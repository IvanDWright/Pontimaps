# Reglas de R8 / ProGuard para PontiMaps (release).
#
# Flutter, flutter_map, geolocator, shared_preferences y Firebase publican sus
# propias reglas de consumidor: no hace falta mantener clases a mano. Solo se
# silencian las referencias opcionales a Play Core (componentes diferidos de
# Flutter que esta app no usa) para que R8 no falle por clases ausentes.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
