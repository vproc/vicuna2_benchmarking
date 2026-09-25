# Telecom benchmark integration

This directory contains benchmark kernels derived from the EEMBC TeleBench
sources and adapted for use with the Vicuna benchmarking framework.

The original EEMBC sources used for this integration are preserved under
`upstream/`.

Integrated workloads:

- Autocorrelation
- Convolutional encoder
- Bit allocation
- Viterbi decoder

The original EEMBC execution harness has been replaced by the Vicuna
benchmarking framework. Therefore, results produced by this integration
should not be considered official TeleBench or Telemark results.

See `LICENSE.md` for the original licensing terms.