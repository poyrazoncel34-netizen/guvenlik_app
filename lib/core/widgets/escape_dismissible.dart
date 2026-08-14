// ============================================================================
// ESCAPE İLE KAPANABİLİR MODAL — klavye kullanıcısı için Back ile eşitlik
// ============================================================================
// BULGU (cihazda ölçüldü, API 36 emülatörü):
//
//   * Escape hiçbir modalı kapatmıyordu — ekranda DEĞİŞEN PİKSEL YOK (0.0000).
//   * Aynı modalı sistem BACK tuşu kapatıyordu ve uygulama sonucu (null) sorunsuz
//     işliyordu. Yani modal aslında KAPANABİLİR; kilitli olan yalnızca klavye yolu.
//   * Nedeni izole edildi: Flutter'ın `_DismissModalAction.isEnabled` fonksiyonu
//     `route.barrierDismissible` döndürür. Bu uygulamadaki 14 `showDialog`
//     çağrısının tamamı `barrierDismissible: false` verdiği için eylem DEVRE DIŞI
//     kalıyor, `Actions.maybeFind` devre dışı eylemi atlayıp yukarı çıkıyor ve
//     Escape'i karşılayan başka bir eylem bulunmuyor.
//   * İkinci ve bağımsız bir kusur: modal açıkken ODAKLANMIŞ TEK DÜĞÜM kök
//     FlutterView'di; modalın İÇİNDE hiçbir şey odakta değildi. `Actions` araması
//     `primaryFocus`tan yukarı yürüdüğü için bu tek başına da Escape'i öldürürdü.
//     (Metin alanı içeren modallarda odak içerideydi ve Escape yine ölüydü —
//     iki kusurun ayrı ayrı var olduğunu bu kanıtladı.)
//
// NE YAPILMIYOR: Escape her modalı kapatmaya ZORLANMIYOR. Bu sarmalayıcı yalnızca
// zaten BACK ile kapanan modallara uygulanır. `PopScope(canPop: false)` ile
// korunan üç modal (geri sayım iptali, acil arama ekranı uyarısı, siren) bilerek
// dışarıda bırakıldı: onlarda Back de kapatmıyor, dolayısıyla Escape'in de
// kapatmaması TUTARLILIK, eksiklik değil. `Navigator.maybePop` zaten PopScope'a
// saygı duyduğu için bu sarmalayıcı yanlışlıkla oraya uygulansa bile kilidi
// kıramaz — güvenli taraf.

import 'package:flutter/material.dart';

/// Escape'i, modalın zaten desteklediği Back davranışına bağlar ve modal
/// açılırken odağın İÇERİDE başlamasını sağlar.
class EscapeDismissible extends StatefulWidget {
  const EscapeDismissible({
    super.key,
    required this.child,
    this.autofocus = true,
  });

  final Widget child;

  /// Kendi metin alanına odak veren modallarda (PIN doğrulama gibi) `false`
  /// verilir: odağı alandan çalmak gerçek bir gerileme olurdu.
  final bool autofocus;

  @override
  State<EscapeDismissible> createState() => _EscapeDismissibleState();
}

class _EscapeDismissibleState extends State<EscapeDismissible> {
  final FocusNode _node = FocusNode(debugLabel: 'EscapeDismissible');

  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) return;
    // NEDEN `Focus(autofocus: true)` DEGIL — bu ayrim cihazda olculdu.
    //
    // `autofocus`, `FocusScope.autofocus(node)` cagirir; bu yalnizca bir NIYET
    // kaydeder ve ancak cevreleyen kapsam odak KAZANIRSA uygulanir. Dokunmatik
    // kullanicinin gercek durumunda uygulamada hicbir seyin odagi yoktur, kapsam
    // hicbir zaman odak kazanmaz, dolayisiyla niyet hic uygulanmaz. Yani
    // `autofocus` tam da duzeltmesi gereken kosulda calismiyordu: widget
    // testinde (kok kapsamin odagi var) gecerken cihazda modal dokunarak
    // acildiginda odaklanan dugum cikmadi ve Escape olu kaldi.
    //
    // `requestFocus()` kosullu degildir: zinciri yukari dogru odaklar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_node.hasFocus) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{DismissIntent: _PopModalAction(context)},
      child: Focus(
        focusNode: _node,
        // Traversal'da durak OLUSTURMAZ: yalnizca baslangic odagini modalin
        // icinde tutmak icin var. Tab ilk gercek denetime gider.
        skipTraversal: true,
        child: widget.child,
      ),
    );
  }
}

class _PopModalAction extends DismissAction {
  _PopModalAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(DismissIntent intent) {
    // maybePop: PopScope(canPop:false) varsa kapatmaz. Kasitli kilitler korunur.
    Navigator.of(context).maybePop();
    return null;
  }
}
