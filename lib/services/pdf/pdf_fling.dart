/// PDF görüntüleyicide parmak bırakılınca kayma (fırlatma) sürtünmesi.
///
/// pdfrx'in `InteractiveViewer`ı fırlatmayı `FrictionSimulation` ile yürütür:
/// gidilen yol ≈ hız / |ln(katsayı)|. Varsayılan 1,35e-5 → 3000 px/sn'lik
/// fırlatma ~270 px'te duruyordu ("birazcık kayıp duruyor", 2026-10-29).
/// 0,08 → ~1190 px; Android'in `OverScroller` eğrisine (~1300 px) yakın.
const double kPdfPanFriction = 0.08;

/// İki parmaklı (yakınlaştırma) jest için pdfrx varsayılanı. Aynı katsayı
/// ×200 yakınlaştırma ataletine giriyor: ≥ 1/200 olunca sürtünme ivmeye
/// döner ve yakınlık parmak kalkınca fırlar — o yüzden pinch'te düşük kalır.
const double kPdfPinchFriction = 0.0000135;
