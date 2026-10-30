/* Rezerwuje początek statycznego TLS glibc (tpidr_el0+16…), w który bionic z Androida 7
 * zapisuje swoje sloty (errno, OPENGL_API, OPENGL, …). Ładować jako pierwszą przez LD_PRELOAD. */
__attribute__((tls_model("initial-exec"), used, aligned(16)))
__thread char hybris_bionic_tls_pad[256];

char *hybris_bionic_tls_pad_addr(void) { return hybris_bionic_tls_pad; }
