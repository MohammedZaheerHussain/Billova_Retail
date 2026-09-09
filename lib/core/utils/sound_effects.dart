// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Lightweight, zero-dependency WebAudio synthesizer for POS acoustic feedback
class SoundEffects {
  SoundEffects._();

  /// Play high-pitch crystal clear retail chime (880Hz / 80ms) for successful barcode scan
  static void playSuccess() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', ['''
        (function() {
          try {
            var AudioContext = window.AudioContext || window.webkitAudioContext;
            if (!AudioContext) return;
            if (!window._skywalkAudioCtx) {
              window._skywalkAudioCtx = new AudioContext();
            }
            var ctx = window._skywalkAudioCtx;
            if (ctx.state === 'suspended') {
              ctx.resume();
            }
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(880, ctx.currentTime); // A5 note
            gain.gain.setValueAtTime(0.12, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.09);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start();
            osc.stop(ctx.currentTime + 0.09);
          } catch(e) {}
        })();
      ''']);
    } catch (_) {}
  }

  /// Play double low-pitch warning buzz (220Hz / 180ms) for out-of-stock / invalid barcode
  static void playError() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', ['''
        (function() {
          try {
            var AudioContext = window.AudioContext || window.webkitAudioContext;
            if (!AudioContext) return;
            if (!window._skywalkAudioCtx) {
              window._skywalkAudioCtx = new AudioContext();
            }
            var ctx = window._skywalkAudioCtx;
            if (ctx.state === 'suspended') {
              ctx.resume();
            }
            // Double buzz
            [0, 0.1].forEach(function(offset) {
              var osc = ctx.createOscillator();
              var gain = ctx.createGain();
              osc.type = 'sawtooth';
              osc.frequency.setValueAtTime(220, ctx.currentTime + offset);
              gain.gain.setValueAtTime(0.15, ctx.currentTime + offset);
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + offset + 0.08);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start(ctx.currentTime + offset);
              osc.stop(ctx.currentTime + offset + 0.08);
            });
          } catch(e) {}
        })();
      ''']);
    } catch (_) {}
  }
}
