// Test 32-bitowego HAL audio (nx591j): ton 440 Hz na głośnik przez audio.primary.
#include <hardware/audio.h>
#include <hardware/hardware.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    const int seconds = argc > 1 ? atoi(argv[1]) : 3;
    const hw_module_t *mod = nullptr;
    int ret = hw_get_module_by_class(AUDIO_HARDWARE_MODULE_ID, "primary", &mod);
    printf("hw_get_module: %d\n", ret);
    if (ret) return 1;

    audio_hw_device_t *dev = nullptr;
    ret = audio_hw_device_open(mod, &dev);
    printf("audio_hw_device_open: %d\n", ret);
    if (ret) return 1;
    printf("init_check: %d\n", dev->init_check(dev));
    dev->set_mode(dev, AUDIO_MODE_NORMAL);

    audio_config_t cfg = AUDIO_CONFIG_INITIALIZER;
    cfg.sample_rate = 48000;
    cfg.channel_mask = AUDIO_CHANNEL_OUT_STEREO;
    cfg.format = AUDIO_FORMAT_PCM_16_BIT;
    audio_stream_out_t *out = nullptr;
    ret = dev->open_output_stream(dev, 1, AUDIO_DEVICE_OUT_SPEAKER,
                                  AUDIO_OUTPUT_FLAG_PRIMARY, &cfg, &out, nullptr);
    printf("open_output_stream: %d\n", ret);
    if (ret) return 1;

    const size_t bytes = out->common.get_buffer_size(&out->common);
    const size_t frames = bytes / 4;
    printf("buffer: %zu B, rate %u\n", bytes, out->common.get_sample_rate(&out->common));
    int16_t buf[frames * 2];
    double phase = 0;
    long total = 0;
    for (long done = 0; done < 48000L * seconds; done += frames) {
        for (size_t i = 0; i < frames; i++) {
            int16_t v = (int16_t)(8000 * sin(phase));
            phase += 2 * M_PI * 440 / 48000;
            buf[2 * i] = buf[2 * i + 1] = v;
        }
        ssize_t w = out->write(out, buf, bytes);
        if (w < 0) { printf("write: %zd\n", w); break; }
        total += w;
    }
    printf("zapisano %ld B\n", total);
    dev->close_output_stream(dev, out);
    audio_hw_device_close(dev);
    return 0;
}
