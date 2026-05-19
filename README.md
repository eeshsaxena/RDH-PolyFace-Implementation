# RDH-PolyFace — Reversible Data Hiding in Encrypted Polygonal Faces

> **Paper:** Yuan-Yu Tsai, *"Reversible Data Hiding in Encrypted Polygonal Faces Using Vertex Index Similarity"*, IEEE Transactions on Multimedia, Vol. 27, pp. 9603-9618, 2025.
> **DOI:** [10.1109/TMM.2025.3613172](https://doi.org/10.1109/TMM.2025.3613172)

## Overview

This repository contains a faithful single-file MATLAB R2025b implementation of the first reversible data hiding (RDH) algorithm that operates on the **polygon index domain** of encrypted 3D models — an embedding space previously unexplored in the literature.

## Key Innovations (from the paper)

| Contribution | Description |
|---|---|
| Polygon index domain | First RDH in encrypted polygon indices (not vertex coords) |
| Right Circular Shifting | Reorders face indices so smallest is first; preserves normal vector |
| HoP/HeP classification | Threshold-T based homogeneity to select prediction strategy |
| LZC prediction | Leading Zero Count for homogeneous faces (Eq. 1, 2) |
| mMSB prediction | Multi-MSB for heterogeneous faces; 4-neighbor reference |
| Hybrid Huffman (HHE) | Separate tree for 1st index, shared for 2nd+3rd |
| Range-preserving XOR (Eq. 3) | Keeps encrypted indices within valid ranges |
| Composable | Compatible with vertex-based RDH; stacking doubles capacity |

## Results (Paper Table VIII, T=10, HHE)

| Metric | Value |
|--------|-------|
| Avg 1st index capacity | 16.21 bpp |
| Avg 2nd index capacity | 8.31 bpp |
| Avg 3rd index capacity | 7.72 bpp |
| **Avg total capacity** | **32.63 bpp** |
| Best baseline (Sui [17]) | 28.00 bpv |

## Usage

```matlab
% Open MATLAB R2025b
cd 'c:\iiitvd\New Paper 19.05.2026\RDH_PolyFace_Matlab'
RDH_PolyFace
```

Expected output:
```
=== RDH in Encrypted Polygonal Faces (Tsai, IEEE TMM 2025) ===
Model:    Bunny (synthetic)  |  Vertices: 1000  Faces: 2000
Total embedding capacity: XXXX bits (XX.XX bpp)
Message recovery:  PASS
Face restoration:  PASS
```

## Files

| File | Description |
|------|-------------|
| `RDH_PolyFace.m` | Complete single-file MATLAB implementation |
| `RDH_PolyFace_Demo_Report.md` | Full demo report (template format) |
| `README.md` | This file |

## Algorithm Flow

```
Input: 3D mesh (V, F), secret message, keys KE, KD, threshold T

1. Right Circular Shifting      → F'  (smallest index first)
2. HoP/HeP Classification       → face types
3. Similarity Calculation       → labels L1, L2, L3 per face
4. Hybrid Huffman Encoding      → aux_bits (compressed labels)
5. Face Encryption (Eq.3)      → F_enc (XOR, range-preserving)
6. Auxiliary Info Embedding     → F_aux (aux_bits in 1st-index bits)
7. Message Encryption + Embed  → F_marked (XOR msg in 2nd/3rd bits)

Receiver:
8. Extract aux_bits             → decode Huffman, get recording info
9. Decrypt message              → XOR with KD stream
10. Restore indices             → LZC or mMSB inverse → original F
```

## Requirements

- MATLAB R2025b (or newer)
- Statistics and Machine Learning Toolbox (for `huffmandict`/`huffmanenco`; fallback encoder included)
