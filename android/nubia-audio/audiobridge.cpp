// nubia-audiobridge: 32-bitowy mostek PulseAudio <-> HAL audio Nubii przez FIFO:
// odtwarzanie (module-pipe-sink -> HAL) i nagrywanie (HAL -> module-pipe-source).
// Na NX591J działa tylko 32-bitowy HAL/ACDB (Android 7 uruchamiał 32-bitowy audioserver),
// a PulseAudio w porcie Sailfisha jest 64-bitowy. Format: s16le, 48 kHz, stereo.
#include <hardware/audio.h>
#include <hardware/hardware.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>

static volatile sig_atomic_t g_stop = 0;
static void on_signal(int) { g_stop = 1; }

static const char *kJackName = "msm8952-snd-card-mtp Headset Jack";
static const int kIdleMs = 500;   // po tylu ms ciszy HAL przechodzi w standby

// Słuchawki: przełączniki SW_HEADPHONE_INSERT / SW_MICROPHONE_INSERT z urządzenia "Headset Jack".
static audio_devices_t output_device() {
    DIR *dir = opendir("/dev/input");
    if (!dir) return AUDIO_DEVICE_OUT_SPEAKER;
    audio_devices_t dev = AUDIO_DEVICE_OUT_SPEAKER;
    while (struct dirent *e = readdir(dir)) {
        if (strncmp(e->d_name, "event", 5)) continue;
        char path[64], name[128] = {0};
        snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
        int fd = open(path, O_RDONLY | O_CLOEXEC);
        if (fd < 0) continue;
        if (ioctl(fd, EVIOCGNAME(sizeof name - 1), name) >= 0 && !strcmp(name, kJackName)) {
            unsigned long sw = 0;
            if (ioctl(fd, EVIOCGSW(sizeof sw), &sw) >= 0) {
                if (sw & (1UL << SW_MICROPHONE_INSERT)) dev = AUDIO_DEVICE_OUT_WIRED_HEADSET;
                else if (sw & (1UL << SW_HEADPHONE_INSERT)) dev = AUDIO_DEVICE_OUT_WIRED_HEADPHONE;
            }
            close(fd);
            break;
        }
        close(fd);
    }
    closedir(dir);
    return dev;
}

static void set_route(audio_stream_out_t *out, audio_devices_t dev) {
    char kv[32];
    snprintf(kv, sizeof kv, "routing=%u", dev);
    out->common.set_parameters(&out->common, kv);
}

// PulseAudio przy (re)starcie potrafi usunąć i założyć FIFO od nowa – wtedy trzeba je otworzyć ponownie.
static bool fifo_replaced(int fd, const char *path) {
    struct stat a, b;
    if (fstat(fd, &a) || stat(path, &b)) return true;
    return a.st_ino != b.st_ino || a.st_dev != b.st_dev;
}

// Nagrywanie: HAL (wbudowany mikrofon) -> FIFO. Gdy nikt nie czyta (FIFO pełne), mikrofon
// przechodzi w standby i wraca, gdy w FIFO zwolni się miejsce.
struct MicArgs { audio_hw_device_t *dev; const char *fifo; };

static void *mic_thread(void *arg) {
    MicArgs *a = static_cast<MicArgs *>(arg);
    audio_config_t cfg = AUDIO_CONFIG_INITIALIZER;
    cfg.sample_rate = 48000;
    cfg.channel_mask = AUDIO_CHANNEL_IN_STEREO;
    cfg.format = AUDIO_FORMAT_PCM_16_BIT;
    audio_stream_in_t *in = nullptr;
    if (a->dev->open_input_stream(a->dev, 2, AUDIO_DEVICE_IN_BUILTIN_MIC, &cfg, &in,
                                  AUDIO_INPUT_FLAG_NONE, "", AUDIO_SOURCE_MIC)) {
        fprintf(stderr, "mikrofon: nie można otworzyć strumienia wejściowego\n");
        return nullptr;
    }
    in->common.set_parameters(&in->common, "input_source=1;routing=-2147483644");
    in->common.standby(&in->common);
    const size_t chunk = in->common.get_buffer_size(&in->common);
    char *buf = static_cast<char *>(malloc(chunk));
    fprintf(stderr, "mikrofon gotowy: bufor %zu B, FIFO %s\n", chunk, a->fifo);

    while (!g_stop) {
        int fd = open(a->fifo, O_RDWR | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) { sleep(1); continue; }
        fcntl(fd, 1031 /* F_SETPIPE_SZ */, 16384);
        bool active = false;
        while (!g_stop) {
            // nagrywaj tylko, gdy czytelnik robi miejsce w FIFO
            struct pollfd p = { fd, POLLOUT, 0 };
            if (poll(&p, 1, active ? 200 : 100) <= 0) {
                if (active) { in->common.standby(&in->common); active = false; }
                if (fifo_replaced(fd, a->fifo)) break;
                continue;
            }
            ssize_t n = in->read(in, buf, chunk);
            if (n <= 0) { usleep(10000); continue; }
            active = true;
            ssize_t w = write(fd, buf, n);
            if (w < 0 && errno == EAGAIN) {   // nikt nie czyta: uśpij mikrofon
                in->common.standby(&in->common);
                active = false;
            }
        }
        close(fd);
    }
    in->common.standby(&in->common);
    a->dev->close_input_stream(a->dev, in);
    return nullptr;
}

int main(int argc, char **argv) {
    const char *fifo = argc > 1 ? argv[1] : "/run/nubia-audio/fifo";
    const char *mic_fifo = argc > 2 ? argv[2] : "/run/nubia-audio/mic";
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);
    signal(SIGPIPE, SIG_IGN);

    const hw_module_t *mod = nullptr;
    audio_hw_device_t *dev = nullptr;
    if (hw_get_module_by_class(AUDIO_HARDWARE_MODULE_ID, "primary", &mod) ||
        audio_hw_device_open(mod, &dev)) {
        fprintf(stderr, "nie można otworzyć HAL audio.primary\n");
        return 1;
    }
    dev->set_mode(dev, AUDIO_MODE_NORMAL);

    MicArgs mic_args = { dev, mic_fifo };
    pthread_t mic;
    pthread_create(&mic, nullptr, mic_thread, &mic_args);

    audio_config_t cfg = AUDIO_CONFIG_INITIALIZER;
    cfg.sample_rate = 48000;
    cfg.channel_mask = AUDIO_CHANNEL_OUT_STEREO;
    cfg.format = AUDIO_FORMAT_PCM_16_BIT;
    audio_stream_out_t *out = nullptr;
    audio_devices_t route = output_device();
    if (dev->open_output_stream(dev, 1, route, AUDIO_OUTPUT_FLAG_PRIMARY, &cfg, &out, nullptr)) {
        fprintf(stderr, "nie można otworzyć strumienia wyjściowego\n");
        return 1;
    }
    const size_t chunk = out->common.get_buffer_size(&out->common);
    char *buf = static_cast<char *>(malloc(chunk));
    fprintf(stderr, "HAL gotowy: bufor %zu B, wyjście 0x%x, FIFO %s\n", chunk, route, fifo);

    bool active = false;
    while (!g_stop) {
        // otwarcie z O_RDWR: FIFO nie dostaje EOF, gdy PulseAudio się zrestartuje
        int fd = open(fifo, O_RDWR | O_CLOEXEC);
        if (fd < 0) { sleep(1); continue; }
        size_t fill = 0;
        while (!g_stop) {
            struct pollfd p = { fd, POLLIN, 0 };
            int pr = poll(&p, 1, kIdleMs);
            if (pr == 0) {                       // cisza: oddaj resztę bufora i uśpij HAL
                if (active) {
                    if (fill) { memset(buf + fill, 0, chunk - fill); out->write(out, buf, chunk); fill = 0; }
                    out->common.standby(&out->common);
                    active = false;
                }
                if (fifo_replaced(fd, fifo)) break;
                continue;
            }
            if (pr < 0) { if (errno == EINTR) continue; break; }
            ssize_t n = read(fd, buf + fill, chunk - fill);
            if (n <= 0) { if (n < 0 && errno == EINTR) continue; break; }
            fill += n;
            if (fill < chunk) continue;
            if (!active) {                       // wybudzenie: sprawdź słuchawki
                audio_devices_t now = output_device();
                if (now != route) { route = now; set_route(out, route); }
                active = true;
            }
            if (out->write(out, buf, chunk) < 0) usleep(10000);
            fill = 0;
        }
        close(fd);
    }
    out->common.standby(&out->common);
    pthread_join(mic, nullptr);
    dev->close_output_stream(dev, out);
    audio_hw_device_close(dev);
    return 0;
}
