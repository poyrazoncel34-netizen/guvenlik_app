// Fails when a production call to `NotificationService.showEmergencyAlert`
// throws its typed outcome away.
//
// Why this exists, and why it is not a regex
// ------------------------------------------
// The rule this supersedes (`_alert_call_sites` in scripts/audit_evidence/
// interaction.py) anchored on the literal string `NotificationService.instance.
// showEmergencyAlert(`. Its consumption analysis was sound; its ENUMERATION was
// a substring match on one receiver spelling, so the single most likely refactor
// in the language --
//
//     final svc = NotificationService.instance;
//     await svc.showEmergencyAlert(...);          // outcome dropped
//
// -- was not merely unflagged, it was never enumerated at all. The docstring
// nevertheless claimed "Every LIVE `showEmergencyAlert` invocation", and three
// audit rows repeated the claim. That is RER-04: a true statement about the
// tree, resting on a check that could not have detected the counterexample.
//
// This verifier resolves the ELEMENT the invocation actually binds to, so the
// receiver's spelling is irrelevant: a hoisted local, a field, a getter, a
// parameter and a direct singleton access all resolve to the same
// `NotificationService.showEmergencyAlert`.
//
// Why a script and not an analyzer plugin
// ---------------------------------------
// A plugin would put this rule in the IDE and in `flutter analyze`, at the cost
// of a plugin package, an `analysis_options.yaml` registration and an API that
// is still moving. For ONE rule over ~170 files that resolves in about ten
// seconds, that is architecture bought for prestige. `package:analyzer` is a
// dev_dependency here -- it ships nothing into the AAB -- and the same element
// model is available from a standalone script.
//
// What it can and cannot see (stated exactly, because the last claim was too big)
// -----------------------------------------------------------------------------
// CAN: any receiver spelling; the wrapper chain, transitively, to a fixpoint;
//      assignment, return, callback hand-off, argument passing, `unawaited`,
//      `.ignore()`, and a dropped expression statement.
// CANNOT: a call reached only through a dynamic receiver or a `Function` value
//      whose target the element model cannot resolve. Such a call is REPORTED
//      as `unresolvedAlertLikeInvocation` rather than silently skipped, so the
//      blind spot is visible instead of assumed empty.
//
// Usage:
//   dart run scripts/verify_alert_outcome_consumption.dart
//   dart run scripts/verify_alert_outcome_consumption.dart --json
//
// Exit code 0 == ALERT_OUTCOME_CONSUMPTION_PASS.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// The method whose typed outcome must never be dropped.
const String kRootTarget = 'NotificationService.showEmergencyAlert';

/// The bare method name, used only to notice invocations the element model
/// could not resolve. Enumeration never depends on it.
const String kRootMethodName = 'showEmergencyAlert';

/// What happened to the value an invocation produced.
enum Consumption {
  /// Stored in a variable or assigned to something.
  assigned,

  /// Returned to the caller. The enclosing NAMED function therefore becomes a
  /// wrapper, and its own call sites are enumerated in turn.
  returned,

  /// Produced inside an anonymous closure that is itself handed to another
  /// call -- the `run: () => ...` pipeline hand-off. The value leaves with the
  /// closure, so the caller of that pipeline owns it.
  handedToCallback,

  /// Passed directly as an argument to another call.
  passedAsArgument,

  /// Evaluated and thrown away.
  dropped,
}

class AlertInvocation {
  AlertInvocation({
    required this.target,
    required this.site,
    required this.consumption,
    required this.enclosing,
    required this.detail,
    required this.escapesViaReturn,
  });

  /// Resolved `Type.method` this invocation binds to.
  final String target;
  final String site;
  final Consumption consumption;

  /// `Type.method` of the NAMED function this invocation sits in, or null when
  /// the nearest enclosing function is an anonymous closure.
  final String? enclosing;
  final String detail;

  /// Whether the outcome leaves the enclosing NAMED function as its return
  /// value -- either returned directly, or stored in a local that the function
  /// then returns. The second form is not a nicety: the ONE real wrapper in
  /// this tree, `SafetyAlertDispatch.postWarning`, is written that way
  /// (`final outcome = await ...; await _record(outcome); return outcome;`),
  /// so a fixpoint that only followed direct returns would have stopped at the
  /// wrapper and never enumerated its callers.
  final bool escapesViaReturn;

  bool get isDropped => consumption == Consumption.dropped;

  Map<String, Object?> toJson() => <String, Object?>{
    'target': target,
    'site': site,
    'consumption': consumption.name,
    'enclosing': enclosing,
    'detail': detail,
    'escapesViaReturn': escapesViaReturn,
  };
}

/// Collects every resolved invocation plus the unresolved look-alikes.
class _InvocationCollector extends RecursiveAstVisitor<void> {
  _InvocationCollector(this.relativePath, this.unit);

  final String relativePath;
  final CompilationUnit unit;
  final List<AlertInvocation> invocations = <AlertInvocation>[];
  final List<String> unresolved = <String>[];

  String _at(int offset) =>
      '$relativePath:${unit.lineInfo.getLocation(offset).lineNumber}';

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final element = node.methodName.element;
    if (element == null) {
      // Only worth reporting when it LOOKS like the thing we care about;
      // unresolved noise elsewhere is not this verifier's business.
      if (node.methodName.name == kRootMethodName) {
        unresolved.add(_at(node.offset));
      }
      return;
    }
    final owner = element.enclosingElement?.name;
    if (owner == null) return;
    final target = '$owner.${element.name}';
    final classified = _classify(node);
    invocations.add(
      AlertInvocation(
        target: target,
        site: _at(node.offset),
        consumption: classified.$1,
        enclosing: _enclosingNamedExecutable(node),
        detail: classified.$2,
        escapesViaReturn:
            classified.$1 == Consumption.returned || _returnsAssignedLocal(node),
      ),
    );
  }

  /// Where this invocation's value goes.
  ///
  /// Walks out through the nodes that PRESERVE a value (`await`, parentheses,
  /// casts, `!`) and then decides on the first node that actually does
  /// something with it.
  (Consumption, String) _classify(MethodInvocation node) {
    AstNode child = node;
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is AwaitExpression ||
          parent is ParenthesizedExpression ||
          parent is AsExpression ||
          parent is PostfixExpression) {
        child = parent;
        parent = parent.parent;
        continue;
      }
      if (parent is VariableDeclaration || parent is AssignmentExpression) {
        return (Consumption.assigned, 'assigned');
      }
      if (parent is ReturnStatement) {
        return (Consumption.returned, 'returned to the caller');
      }
      if (parent is ExpressionFunctionBody) {
        // `=> call(...)`. A NAMED function returns it; an anonymous closure
        // hands it to whoever invokes the closure.
        return _enclosingNamedExecutable(node) == null
            ? (Consumption.handedToCallback, 'returned from a callback')
            : (Consumption.returned, 'returned to the caller');
      }
      if (parent is ExpressionStatement) {
        return (Consumption.dropped, 'expression statement; result discarded');
      }
      if (parent is ArgumentList) {
        final AstNode? call = parent.parent;
        final String? name = call is MethodInvocation
            ? call.methodName.name
            : null;
        // `unawaited(x)` is an explicit fire-and-forget, but it handles no
        // error and inspects no outcome, so it is exactly the "deliberately
        // dropped" shape this rule exists to reject.
        if (name == 'unawaited') {
          return (
            Consumption.dropped,
            'wrapped in unawaited(); no outcome is inspected',
          );
        }
        return (Consumption.passedAsArgument, 'passed to ${name ?? 'a call'}');
      }
      if (parent is MethodInvocation) {
        // Only a CHAINED call on our result matters here; being the argument
        // of another call is handled by the ArgumentList branch above.
        if (identical(parent.target, child)) {
          if (parent.methodName.name == 'ignore') {
            return (Consumption.dropped, '.ignore() discards the outcome');
          }
          // `.then(...)`, `.catchError(...)`, `.whenComplete(...)` keep a
          // value; follow the chain rather than guessing about it.
          child = parent;
          parent = parent.parent;
          continue;
        }
        return (Consumption.passedAsArgument, 'passed to a call');
      }
      if (parent is CascadeExpression) {
        return (Consumption.dropped, 'cascade discards the outcome');
      }
      // Anything else that reads the value (interpolation, comparison,
      // collection literal, conditional) genuinely consumes it.
      return (Consumption.passedAsArgument, 'used as a value');
    }
    return (Consumption.dropped, 'no enclosing expression consumes the result');
  }

  /// Whether this invocation is stored in a local that the enclosing NAMED
  /// function then returns.
  ///
  /// Deliberately narrow: ONE assignment to a simple local, and a `return` of
  /// that same identifier somewhere in the same body. It is not general
  /// dataflow, and it does not pretend to be -- but it is exactly the shape a
  /// wrapper is written in, and it is decidable without guessing.
  bool _returnsAssignedLocal(MethodInvocation node) {
    final declaration = node.thisOrAncestorOfType<VariableDeclaration>();
    if (declaration == null) return false;
    final String name = declaration.name.lexeme;

    final AstNode? body =
        node.thisOrAncestorOfType<MethodDeclaration>()?.body ??
        node.thisOrAncestorOfType<FunctionDeclaration>()?.functionExpression.body;
    if (body == null) return false;

    final finder = _ReturnsIdentifier(name);
    body.accept(finder);
    return finder.found;
  }

  /// `Type.method` of the nearest NAMED enclosing function, or null when the
  /// nearest enclosing function is an anonymous closure.
  String? _enclosingNamedExecutable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression &&
          current.parent is! FunctionDeclaration) {
        return null; // anonymous closure encountered first
      }
      if (current is MethodDeclaration) {
        final String owner =
            current.thisOrAncestorOfType<ClassDeclaration>()?.name.lexeme ??
            current.thisOrAncestorOfType<MixinDeclaration>()?.name.lexeme ??
            '<unnamed>';
        return '$owner.${current.name.lexeme}';
      }
      if (current is FunctionDeclaration) {
        return 'top-level.${current.name.lexeme}';
      }
      current = current.parent;
    }
    return null;
  }
}

/// `return <name>;` anywhere in a body.
class _ReturnsIdentifier extends RecursiveAstVisitor<void> {
  _ReturnsIdentifier(this.name);
  final String name;
  bool found = false;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final Expression? value = node.expression;
    if (value is SimpleIdentifier && value.name == name) found = true;
    super.visitReturnStatement(node);
  }
}

Future<int> run(String root, {required bool asJson}) async {
  final collection = AnalysisContextCollection(includedPaths: <String>[root]);
  final all = <AlertInvocation>[];
  final unresolved = <String>[];
  var filesAnalyzed = 0;

  for (final context in collection.contexts) {
    for (final path in context.contextRoot.analyzedFiles()) {
      if (!path.endsWith('.dart')) continue;
      // Production code only. A test is allowed to drop an outcome.
      if (!path.startsWith('$root/lib/')) continue;
      filesAnalyzed++;
      final result = await context.currentSession.getResolvedUnit(path);
      if (result is! ResolvedUnitResult) continue;
      final collector = _InvocationCollector(
        path.replaceFirst('$root/', ''),
        result.unit,
      );
      result.unit.accept(collector);
      all.addAll(collector.invocations);
      unresolved.addAll(collector.unresolved);
    }
  }

  // Fixpoint over the wrapper chain: a function that RETURNS an alert outcome
  // is itself an alert-outcome producer, and its own call sites must consume.
  final targets = <String>{kRootTarget};
  var changed = true;
  while (changed) {
    changed = false;
    for (final invocation in all) {
      if (!targets.contains(invocation.target)) continue;
      if (!invocation.escapesViaReturn) continue;
      final String? wrapper = invocation.enclosing;
      if (wrapper != null && targets.add(wrapper)) changed = true;
    }
  }

  final tracked = all.where((i) => targets.contains(i.target)).toList()
    ..sort((a, b) => a.site.compareTo(b.site));
  final violations = <Map<String, Object?>>[
    for (final invocation in tracked.where((i) => i.isDropped))
      <String, Object?>{
        'rule': 'alertOutcomeDiscardedAtCallSite',
        'site': invocation.site,
        'target': invocation.target,
        'detail': invocation.detail,
      },
    for (final site in unresolved)
      <String, Object?>{
        'rule': 'unresolvedAlertLikeInvocation',
        'site': site,
        'target': kRootMethodName,
        'detail':
            'an invocation named $kRootMethodName whose target the element '
            'model could not resolve; it cannot be proven to consume its '
            'outcome, so it is reported rather than assumed safe',
      },
  ];

  if (asJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'verifier': 'scripts/verify_alert_outcome_consumption.dart',
        'filesAnalyzed': filesAnalyzed,
        'resolvedTargets': targets.toList()..sort(),
        'invocations': tracked.map((i) => i.toJson()).toList(),
        'violations': violations,
      }),
    );
  }

  if (violations.isNotEmpty) {
    stdout.writeln('ALERT_OUTCOME_CONSUMPTION_FAIL');
    for (final violation in violations) {
      stdout.writeln(
        '- ${violation['rule']} ${violation['site']} '
        '(${violation['target']}): ${violation['detail']}',
      );
    }
    return 1;
  }

  stdout.writeln(
    'ALERT_OUTCOME_CONSUMPTION_PASS files=$filesAnalyzed '
    'targets=${targets.length} sites=${tracked.length} violations=0',
  );
  for (final invocation in tracked) {
    stdout.writeln(
      '  ${invocation.site} ${invocation.target} '
      '-> ${invocation.consumption.name} (${invocation.detail})',
    );
  }
  return 0;
}

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  exitCode = await run(root, asJson: args.contains('--json'));
}
