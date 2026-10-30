// Test 32-bitowego HAL audio (nx591j): nagranie z mikrofonu do pliku (s16le 48 kHz stereo).
#include <hardware/audio.h>
#include <hardware/hardware.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "/tmp/rec.raw";
    const int seconds = argc > 2 ? atoi(argv[2]) : 3;
    const hw_module_t *mod = nullptr;
    audio_hw_device_t *dev = nullptr;
    if (hw_get_module_by_class(AUDIO_HARDWARE_MODULE_ID, "primary", &mod) || audio_hw_device_open(mod, &dev)) {
        printf("HAL: błąd\n");
        return 1;
    }
    audio_config_t cfg = AUDIO_CONFIG_INITIALIZER;
    cfg.sample_rate = 48000;
    cfg.channel_mask = AUDIO_CHANNEL_IN_STEREO;
    cfg.format = AUDIO_FORMAT_PCM_16_BIT;
    audio_stream_in_t *in = nullptr;
    int ret = dev->open_input_stream(dev, 2, AUDIO_DEVICE_IN_BUILTIN_MIC, &cfg, &in,
                                     AUDIO_INPUT_FLAG_NONE, "", AUDIO_SOURCE_MIC);
    printf("open_input_stream: %d (rate %u)\n", ret, cfg.sample_rate);
    if (ret) return 1;
    in->common.set_parameters(&in->common, "input_source=1;routing=-2147483644");
    const size_t bytes = in->common.get_buffer_size(&in->common);
    char *buf = static_cast<char *>(malloc(bytes));
    FILE *f = fopen(path, "wb");
    long total = 0, peak = 0;
    while (total < 48000L * 4 * seconds) {
        ssize_t n = in->read(in, buf, bytes);
        if (n <= 0) { printf("read: %zd\n", n); break; }
        fwrite(buf, 1, n, f);
        for (ssize_t i = 0; i + 1 < n; i += 2) {
            long v = labs((long)*(int16_t *)(buf + i));
            if (v > peak) peak = v;
        }
        total += n;
    }
    fclose(f);
    printf("nagrano %ld B, szczyt amplitudy %ld\n", total, peak);
    dev->close_input_stream(dev, in);
    audio_hw_device_close(dev);
    return 0;
}
