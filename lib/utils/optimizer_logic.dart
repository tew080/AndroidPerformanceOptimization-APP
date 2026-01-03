class OptimizerLogic {
  // --- Menu 1: Set Max Refresh Rate ---
  static List<String> getRefreshRateCommands(int hz, bool isVivo) {
    List<String> cmds = [];
    String hzs = "$hz";

    // Standard Settings
    cmds.add('settings put global peak_refresh_rate $hzs.0');
    cmds.add('settings put global min_refresh_rate $hzs.0');
    cmds.add('settings put global user_refresh_rate $hzs.0');
    cmds.add('settings put system peak_refresh_rate $hzs.0');
    cmds.add('settings put system min_refresh_rate $hzs.0');
    cmds.add('settings put system user_refresh_rate $hzs.0');

    // Vivo Specific
    if (isVivo) {
      cmds.add('settings put global vivo_screen_refresh_rate_mode $hz');
    }

    // ROG Phone 6D Logic (Sf Duration)
    String lateSf = "",
        lateApp = "",
        earlySf = "",
        earlyApp = "",
        earlyGlSf = "",
        earlyGlApp = "";
    if (hz == 60) {
      lateSf = "15600000";
      lateApp = "16600000";
      earlySf = "15600000";
      earlyApp = "16600000";
      earlyGlSf = "15600000";
      earlyGlApp = "16600000";
    } else if (hz == 90) {
      lateSf = "13100000";
      lateApp = "19200000";
      earlySf = "13100000";
      earlyApp = "19200000";
      earlyGlSf = "13100000";
      earlyGlApp = "19200000";
    } else if (hz == 120) {
      lateSf = "8333333";
      lateApp = "8333333";
      earlySf = "8333333";
      earlyApp = "8333333";
      earlyGlSf = "8333333";
      earlyGlApp = "8333333";
    } else if (hz == 144) {
      lateSf = "6944443";
      lateApp = "6944443";
      earlySf = "6944443";
      earlyApp = "6944443";
      earlyGlSf = "6944443";
      earlyGlApp = "6944443";
    } else if (hz == 165) {
      lateSf = "6060606";
      lateApp = "6060606";
      earlySf = "6060606";
      earlyApp = "6060606";
      earlyGlSf = "6060606";
      earlyGlApp = "6060606";
    }

    if (lateSf.isNotEmpty) {
      cmds.add('setprop debug.sf.late.sf.duration $lateSf');
      cmds.add('setprop debug.sf.late.app.duration $lateApp');
      cmds.add('setprop debug.sf.early.sf.duration $earlySf');
      cmds.add('setprop debug.sf.early.app.duration $earlyApp');
      cmds.add('setprop debug.sf.earlyGl.sf.duration $earlyGlSf');
      cmds.add('setprop debug.sf.earlyGl.app.duration $earlyGlApp');
    }

    // Additional Props
    cmds.add('setprop debug.sf.frame_rate_multiple_threshold $hz');
    cmds.add('setprop debug.sf_frame_rate_multiple_fences $hz');
    cmds.add('setprop debug.sf.game_default_frame_rate_override $hz');

    return cmds;
  }

  // --- Menu 2: Set RAM Size ---
  static List<String> getRamOptimizationCommands(int ramGb) {
    List<String> cmds = [];

    // Map values based on batch script logic
    int smallW = 1024, smallH = 1024, largeW = 2048, largeH = 1024;
    int layer = 96, path = 48, texture = 96, rBuffer = 8, dropShadow = 6;
    double flush = 0.45;

    if (ramGb == 2) {
      smallW = 512;
      smallH = 512;
      largeW = 1024;
      largeH = 512;
      layer = 24;
      path = 16;
      texture = 32;
      rBuffer = 4;
      dropShadow = 2;
      flush = 0.3;
    } else if (ramGb == 3) {
      smallW = 512;
      smallH = 512;
      largeW = 1024;
      largeH = 512;
      layer = 32;
      path = 16;
      texture = 48;
      rBuffer = 4;
      dropShadow = 3;
      flush = 0.35;
    } else if (ramGb == 4) {
      smallW = 1024;
      smallH = 512;
      largeW = 1024;
      largeH = 1024;
      layer = 48;
      path = 24;
      texture = 64;
      rBuffer = 6;
      dropShadow = 4;
      flush = 0.4;
    } else if (ramGb == 6) {
      smallW = 1024;
      smallH = 512;
      largeW = 2048;
      largeH = 1024;
      layer = 64;
      path = 32;
      texture = 72;
      rBuffer = 6;
      dropShadow = 5;
      flush = 0.4;
    } else if (ramGb == 8) {
      // Default set above
    } else if (ramGb == 12) {
      smallW = 1024;
      smallH = 1024;
      largeW = 2048;
      largeH = 1024;
      layer = 128;
      path = 64;
      texture = 128;
      rBuffer = 8;
      dropShadow = 8;
      flush = 0.5;
    } else if (ramGb == 16) {
      smallW = 2048;
      smallH = 1024;
      largeW = 2048;
      largeH = 2048;
      layer = 160;
      path = 96;
      texture = 160;
      rBuffer = 8;
      dropShadow = 10;
      flush = 0.5;
    } else if (ramGb == 24) {
      smallW = 2048;
      smallH = 1024;
      largeW = 2048;
      largeH = 2048;
      layer = 192;
      path = 128;
      texture = 192;
      rBuffer = 8;
      dropShadow = 12;
      flush = 0.5;
    }

    cmds.add('setprop debug.hwui.text_small_cache_width $smallW');
    cmds.add('setprop debug.hwui.text_small_cache_height $smallH');
    cmds.add('setprop debug.hwui.text_large_cache_width $largeW');
    cmds.add('setprop debug.hwui.text_large_cache_height $largeH');
    cmds.add('setprop debug.hwui.layer_cache_size $layer');
    cmds.add('setprop debug.hwui.path_cache_size $path');
    cmds.add('setprop debug.hwui.texture_cache_size $texture');
    cmds.add('setprop debug.hwui.r_buffer_cache_size $rBuffer');
    cmds.add('setprop debug.hwui.gradient_cache_size 1');
    cmds.add('setprop debug.hwui.drop_shadow_cache_size $dropShadow');
    cmds.add('setprop debug.hwui.texture_cache_flushrate $flush');

    return cmds;
  }

  // --- Menu 3: Skia Render Engine ---
  static List<String> getSkiaCommands(bool useVulkan) {
    List<String> cmds = [];
    cmds.add('device_config put systemui enable_hw_accelerated_canvas true');
    cmds.add('settings put global render_shadows_in_compositor 1');

    if (useVulkan) {
      // Option 1: SkiaVK
      cmds.addAll([
        'setprop debug.hwui.renderer skiavk',
        'setprop debug.hwui.default_renderer skiavk',
        'setprop debug.renderengine.backend skiavkthreaded',
        'setprop debug.hwui.renderengine.backend skiavkthreaded',
        'setprop debug.hwui.use_vulkan true',
        'setprop debug.hwui.force_vulkan true',
        'setprop debug.hwui.disable_opengl true',
        'setprop debug.skia.vulkan_as_default true',
        'setprop debug.sf.enable_hwc_vulkan true',
      ]);
    } else {
      // Option 2: SkiaGL
      cmds.addAll([
        'setprop debug.hwui.renderer skiagl',
        'setprop debug.hwui.default_renderer skiagl',
        'setprop debug.renderengine.backend skiaglthreaded',
        'setprop debug.hwui.renderengine.backend skiaglthreaded',
        'setprop debug.hwui.use_vulkan false',
        'setprop debug.hwui.force_vulkan false',
        'setprop debug.hwui.disable_opengl false',
        'setprop debug.skia.vulkan_as_default false',
      ]);
    }

    // Common optimizations
    cmds.addAll([
      'setprop debug.renderthread.skia.reduceopstasksplitting true',
      'setprop debug.renderengine.capture_skia_ms 0',
      'setprop debug.renderengine.skia_atrace_enabled false',
      'setprop debug.hwui.skia_use_perfetto_track_events false',
      'setprop debug.hwui.skia_tracing_enabled false',
    ]);

    // Note: The script forces restart of SystemUI and Apps.
    // In App, we might just warn user to Reboot.
    return cmds;
  }

  // --- Menu 9: Disable V-Sync ---
  static List<String> getDisableVSync() {
    return [
      'setprop debug.egl.swapinterval 0',
      'setprop debug.gr.swapinterval 0',
      'setprop debug.gpurend.vsync false',
      'setprop debug.hwui.disable_vsync true',
    ];
  }

  // --- Menu 10: Touch Optimization ---
  static List<String> getTouchOptimization(String ms, bool isVivo) {
    List<String> commands = [
      'setprop debug.sf.touch_latency_opt 1',
      'setprop debug.sf.set_touch_timer_ms $ms',
      'setprop touch.deviceType touchScreen',
      'setprop touch.gestureMode spots',
      'setprop touch.orientation.calibration none',
      'setprop touch.pressure.calibration amplitude',
      'setprop touch.pressure.scale 0.001',
      'setprop touch.size.calibration diameter',
      'setprop touch.size.scale 1',
      'setprop touch.size.bias 0',
      'setprop touch.size.isSummed 0',
      'setprop MultitouchSettleInterval 1ms',
      'setprop MultitouchMinDistance 1px',
      'setprop TapInterval 1ms',
      'setprop TapSlop 1px',
    ];

    if (isVivo) {
      commands.addAll([
        'settings put system game_touch_opt 1',
        'settings put global game_touch_opt 1',
        'am broadcast -a com.android.mgr.GAME_MODE_STATE_CHANGED --ei state 1',
        'cmd power set-mode 0',
        'setprop sys.game.touch.opt.enable 1',
      ]);
    }

    return commands;
  }

  // --- Menu 11: Disable AA ---
  static List<String> getDisableAA() {
    return [
      'setprop debug.egl.force_ssaa false',
      'setprop debug.egl.force_smaa false',
      'setprop debug.egl.force_taa false',
      'setprop debug.egl.force_msaa false',
      'setprop debug.egl.force_fxaa false',
    ];
  }

  // --- Menu 12: GPU & HW Acceleration ---
  static List<String> getGpuOptimization(bool isSnapdragon, bool enableTuning) {
    List<String> cmds = [];
    if (isSnapdragon) {
      cmds.add('setprop debug.gralloc.enable_fb_ubwc 1');
    }
    if (enableTuning) {
      cmds.add('setprop debug.performance.tuning 1');
    }
    cmds.add('setprop debug.sf.hw 1');
    cmds.add('setprop debug.video.accelerate.hw 1');
    return cmds;
  }

  // --- Menu 14: Refresh Rate Optimization (HWUI tweaks) ---
  static List<String> getRefreshRateOptimization() {
    return [
      'setprop debug.graphics.game_default_frame_rate.disabled 1',
      'setprop debug.hwui.fps_divisor -1',
      'setprop debug.hwui.skia_atrace_enabled false',
      'setprop debug.hwui.skia_tracing_enabled false',
      'setprop debug.hwui.disable_draw_defer true',
      'setprop debug.hwui.disable_draw_reorder false',
      'setprop debug.hwui.render_ahead 2',
      'setprop debug.hwui.use_hint_manager true',
      'setprop debug.hwui.use_gpu_pixel_buffers true',
      'setprop debug.hwui.skip_empty_damage true',
      'setprop debug.hwui.use_buffer_age true',
      'setprop debug.hwui.use_partial_updates false',
      'setprop debug.hwui.render_dirty_regions false',
      'setprop debug.hwui.early_z 1',
      'setprop debug.hwui.render_thread_priority 1',
      'setprop debug.hwui.skip_eglmanager_telemetry true',
      'setprop debug.hwc.asyncdisp 1',
      'setprop debug.hwui.trace_gpu_resources false',
      'setprop debug.gr.numframebuffers 3',
      'setprop debug.sf.vsp_trace false',
    ];
  }

  static List<String> getJunkCleanerCommands() {
    return [
      "echo 'Analyzing storage...'",

      // 1. สั่ง Android ให้ล้าง Cache ของระบบ (เทคนิค: สั่งให้คืนพื้นที่จำนวนมหาศาล ระบบจะลบ cache อัตโนมัติ)
      "echo 'Trimming System Caches...'",
      "pm trim-caches 999999M",

      // 2. ลบ Cache ในหน่วยความจำภายนอก (Android 11+ เข้าถึงได้ด้วย Shizuku เท่านั้น)
      "echo 'Cleaning External App Cache...'",
      "rm -rf /sdcard/Android/data/*/cache/*",
      "rm -rf /sdcard/Android/data/*/code_cache/*",

      // 3. ลบไฟล์โฆษณาหรือ Cache ของบางแอพที่ชอบซ่อนไว้ (ระวังอย่าลบมั่ว)
      "rm -rf /sdcard/Android/data/*/files/cache/*",
      "rm -rf /sdcard/Android/data/*/files/tombstones/*",

      // 4. ลบไฟล์ขยะชั่วคราวของระบบ
      "echo 'Cleaning Temporary Files...'",
      "rm -rf /data/local/tmp/*",

      // 5. ลบ Log เก่าๆ ที่ทำให้เครื่องหนัก
      "echo 'Cleaning System Logs...'",
      "rm -rf /data/anr/*",
      "rm -rf /data/tombstones/*",
      "rm -rf /data/system/dropbox/*",

      "echo '✅ Cleanup Complete!'",
    ];
  }
}
