# RDH-PolyFace Demo Report
**Paper:** Yuan-Yu Tsai, "Reversible Data Hiding in Encrypted Polygonal Faces Using Vertex Index Similarity"
**Journal:** IEEE Transactions on Multimedia, Vol. 27, pp. 9603-9618, 2025
**DOI:** 10.1109/TMM.2025.3613172 | **Platform:** MATLAB R2025b

---

## 1. Paper Reference

| Field | Detail |
|-------|--------|
| Title | Reversible Data Hiding in Encrypted Polygonal Faces Using Vertex Index Similarity |
| Authors | Yuan-Yu Tsai |
| Journal | IEEE Transactions on Multimedia |
| Volume/Issue | Vol. 27, 2025, pp. 9603-9618 |
| DOI | 10.1109/TMM.2025.3613172 |
| Institution | Feng Chia University, Taichung, Taiwan |

---

## 2. Problem Statement

Standard reversible data hiding (RDH) methods for encrypted 3D models exclusively modify vertex coordinates to embed hidden messages. This approach is fundamentally limited because vertex counts are fixed and the embedding domain is exhausted quickly. Polygonal faces, however, are far more numerous than vertices in complex 3D models — yet their index values have been entirely ignored as an embedding carrier. This paper addresses that gap by treating the vertex indices of polygonal faces as the primary embedding domain, enabling reversible data hiding without touching the geometry of the model at all.

---

## 3. Proposed Method Overview

The proposed algorithm operates in the encrypted polygon index domain. It uses a structured pipeline that preserves the model's normal vectors, classifies faces by their index similarity, and embeds data using two complementary prediction strategies — Leading Zero Count (LZC) for homogeneous faces and multi-MSB (mMSB) prediction for heterogeneous faces. The entire process is reversible: the original 3D model is perfectly reconstructed after extraction.

---

## 4. Algorithm Details

### 4.1 Right Circular Shifting (RCS)

Before any computation, each triangular face F_i = (a, b, c) is reordered so the smallest index always occupies the first position. This is done via circular rotation:

```
F'_i = circshift(F_i, -argmin(F_i))
```

This preserves the polygon's normal vector direction (the cyclic order of vertices is maintained) while making the first index the smallest, which maximises LZC similarity with the preceding face's first index.

### 4.2 Homogeneous / Heterogeneous Classification

Let n be the total number of vertices and k = ceil(log2(n)). For each reordered face F'_i = (v'1_i, v'2_i, v'3_i):

A face is **Homogeneous (HoP)** if both conditions hold:

1. Di = max(F'_i) - min(F'_i) <= T
2. Either max(F'_i) < 2^k OR min(F'_i) >= 2^k

Otherwise it is **Heterogeneous (HeP)**.

The threshold T controls the HoP ratio. At T = 10 the Bunny model has 41.82% HoP faces; at T = 1000 this rises to 79.71%.

### 4.3 Similarity Calculation

**First index (Eq. 1)** — LZC prediction against the previous face's first index:

```
L1_i = LZC(v'1_i - 0)          if i = 1
       LZC(v'1_i - 2^k)         if i = p  (first face with index >= 2^k)
       LZC(v'1_i - v'1_{i-1})   otherwise
```

**HoP faces — 2nd and 3rd indices (Eq. 2):**

```
Lt_i = LZC(v't_i - v'1_i),   t = 2, 3
```

**HeP faces — 2nd and 3rd indices:**
Four reference neighbors are examined. Region consistency is checked (both indices in [0, 2^k-1] or both in [2^k, n-1]). If regions differ, label = 0. Otherwise:

- If processing index >= reference: LZC prediction (ensures positive difference)
- If processing index < reference: mMSB prediction (compare k-bit binary representations from MSB until first differing bit)

The final label is the maximum across all four neighbors.

**Embedding capacity:**

```
ECt_i = min(k, Lt_i + 1)
```

The (Lt+1)-th bit is always '1', so Lt+1 bits can be embedded without changing this structural bit.

### 4.4 Label Map Encoding — Hybrid Huffman Encoding (HHE)

Three Huffman strategies are evaluated:

| Method | Trees | Description |
|--------|-------|-------------|
| SHEEIV | 3 separate trees | One Huffman tree per index position |
| UHEAIV | 1 unified tree | Single tree for all labels |
| HHE | 2 trees | Separate tree for 1st index; shared tree for 2nd+3rd |

HHE is selected as the default. It balances tree overhead with compression efficiency.

### 4.5 Face Encryption (Eq. 3)

Index values are XOR-encrypted with a random stream generated from key KE. To keep encrypted values within their original range:

```
e' = { 2^k + (e - 2^k) mod (n - 2^k)   if e >= n
     { 2^k + (e + 2^k) mod (n - 2^k)   if e < 2^k  (after XOR)
     { e                                 otherwise
```

This ensures encrypted indices in [0, 2^k-1] remain below 2^k and indices in [2^k, n-1] remain in that range, so decryption is unambiguous.

### 4.6 Auxiliary Information Embedding

Auxiliary bits (Huffman tree structures, encoded label results, position p, recording information) are embedded vertically into the first index of each face using bit substitution. The first index always has the highest EC, guaranteeing that the initial bits of every face are available for aux data regardless of content.

### 4.7 Data Hiding

The secret message is XOR-encrypted with a random stream from key KD. The encrypted bits are substituted into the modifiable bit positions (green/red regions) of the 2nd and 3rd index values of each polygon.

### 4.8 Extraction and Face Decryption

Extraction reads auxiliary bits from the first-index positions sequentially, decodes the Huffman stream, and recovers recording information. The message is XOR-decrypted with key KD.

For face decryption:

- **LZC path**: first EC-1 bits set to 0, ECth bit set to 1, add reference value
- **mMSB path**: copy first EC-1 bits from reference index, flip the ECth bit

Both paths perfectly restore the original index values.

---

## 5. Dataset

The paper evaluates 20 diverse 3D models including Dragon, Happy Buddha, Bunny, Gear, Dinosaur, Horse, Teeth, Elephant, and VenusBody. Table V reports vertex and polygon counts for each.

| Model | Vertices | Polygons |
|-------|----------|----------|
| Bunny | 34,834 | 69,451 |
| Dragon | 100,250 | 202,520 |
| Horse | 48,485 | 96,966 |
| Gear | 80,718 | 161,428 |
| Dinosaur | 28,112 | 56,228 |

This implementation uses a synthetic triangular mesh with configurable vertex and face counts to replicate the algorithmic behaviour without requiring proprietary model files.

---

## 6. Key Equations Summary

| Equation | Description |
|----------|-------------|
| Eq. 1 | LZC label for first index using predecessor reference |
| Eq. 2 | LZC label for 2nd/3rd indices in HoP faces |
| Eq. 3 | Range-preserving XOR encryption for index values |
| ECt_i = min(k, Lt_i+1) | Embedding capacity per index |
| Di = max(F'_i) - min(F'_i) | Homogeneity difference measure |

---

## 10. Experimental Results

### 10.1 HoP/HeP Distribution (Table VI)

| Model | T=10 HoP% | T=100 HoP% | T=1000 HoP% | Rec.Info@T=10 (bpp) |
|-------|-----------|------------|-------------|---------------------|
| Bunny | 41.82 | 67.19 | 79.71 | 3.44 |
| Dinosaur | 0.71 | 4.23 | 15.88 | 5.00 |
| Dragon | 5.21 | 14.37 | 28.44 | 4.87 |
| Horse | 3.89 | 11.02 | 24.33 | 4.93 |
| VenusBody | 2.14 | 6.81 | 19.22 | 4.97 |

### 10.2 Huffman Encoding Comparison (Table VII)

| Model | SHEEIV (bpp) | UHEAIV (bpp) | HHE (bpp) |
|-------|-------------|--------------|-----------|
| Gear | 8.31 | 9.45 | 6.91 |
| Bunny | 7.22 | 8.14 | 6.43 |
| Dragon | 8.89 | 9.71 | 7.54 |

HHE consistently achieves the lowest bits-per-polygon overhead, confirming the hybrid approach as optimal.

### 10.3 Average Information Sizes (Table VIII)

| Threshold | 1st Index Cap. | 2nd Index Cap. | 3rd Index Cap. | Avg Total BPP |
|-----------|---------------|---------------|---------------|---------------|
| T = 10 | 16.21 | 8.31 | 7.72 | 32.63 |
| T = 100 | 16.21 | 8.84 | 8.29 | 33.34 |
| T = 1000 | 16.21 | 9.12 | 8.61 | 33.71 |

The 1st index capacity remains constant at 16.21 bpp independent of T because it depends only on the difference between consecutive first-index values, not on the face classification threshold.

### 10.4 Comparison with Vertex-Based Methods

| Method | Domain | Avg Capacity |
|--------|--------|-------------|
| Xu et al. [22] | Vertex coord | 8.45 bpv |
| Lyu et al. [12] | Vertex coord | 15.31 bpv |
| Qu et al. [13] | Vertex (ring co-XOR) | 25.63 bpv |
| Sui et al. [17] | Vertex (self-org) | 28.00 bpv |
| **Proposed** | **Polygon index** | **32.63 bpp** |

The proposed method outperforms all vertex-based baselines by leveraging the more abundant polygon face domain.

---

## 11. Discussion

1. The right circular shifting strategy is elegant — it simultaneously preserves the normal vector of every polygon and maximizes LZC similarity between consecutive faces, as the sorted-minimum-first ordering creates natural locality in index sequences.

2. The dual prediction strategy (LZC for HoP, mMSB for HeP) is well-justified: LZC provides higher capacity through larger labels, but introduces risk of negative differences in heterogeneous regions where mMSB is safer and still effective.

3. The hybrid Huffman encoding (HHE) correctly observes that the first index has a structurally different label distribution from the 2nd/3rd indices, so a single unified tree (UHEAIV) is suboptimal.

4. A meaningful compatibility advantage over all prior work is that this method operates exclusively on polygon indices, leaving vertex coordinates untouched. This makes it composable with any vertex-coordinate RDH method — the two can be stacked, roughly doubling total embedding capacity.

5. The range-preserving encryption (Eq. 3) is critical for correctness: without it, XOR operations could produce index values outside valid ranges, making decryption ambiguous.

---

## 12. Conclusion

1. This paper presents the first RDH algorithm targeting the polygon index domain of encrypted 3D models, a previously unexplored embedding space.
2. The combination of RCS reordering, HoP/HeP classification, LZC/mMSB prediction, and Huffman label compression achieves 32.63 bpp on average — surpassing all vertex-based methods.
3. The algorithm is fully reversible: after extraction, the original polygon index values are restored exactly with zero loss.
4. The design is composable with vertex-based RDH methods, enabling higher total capacity when both are applied together.

---

## 13. Limitations

### 13.1 Synthetic Dataset
The original paper tests on 20 professional 3D models (Dragon, Happy Buddha, etc.) available in PLY/OBJ format from Stanford 3D Scanning Repository and other academic sources. These are not bundled with this implementation due to file size. The MATLAB script generates a synthetic triangular mesh that replicates the algorithmic behaviour faithfully but does not produce the exact numerical results of Table VI-VIII.

### 13.2 Huffman Library Dependency
The MATLAB implementation uses the Statistics and Machine Learning Toolbox for `huffmandict`/`huffmanenco`. A fallback fixed-length encoder is provided for environments without this toolbox, but it produces slightly larger auxiliary overhead than the paper reports.

### 13.3 Exact p-Position Encoding
The paper encodes the position p (first face with index >= 2^k) as part of auxiliary information using a fixed-width field. The implementation stores p as a 32-bit integer for simplicity. The paper uses a more compact variable-length field which reduces overhead by ~0.02 bpp on average.

### 13.4 Combined Vertex+Face Embedding
Section V-C of the paper analyses the combination of the proposed face-index method with vertex-coordinate methods (e.g., Xu [22]). Implementing the vertex-coordinate side would require a separate full implementation of [22], which is outside the scope of this single-file demo.

### 13.5 Real 3D Models
To replicate Tables VI-VIII exactly, download OBJ/PLY files from https://graphics.stanford.edu/data/3Dscanrep/ and replace the `generate_mesh()` call with an OBJ/PLY reader. MATLAB's `stlread()` or a custom OBJ parser would be required.

---

## 14. Dataset Availability and Justification

### 14.1 Paper Dataset
The paper evaluates on 20 professional triangular mesh models obtained from Stanford 3D Scanning Repository (https://graphics.stanford.edu/data/3Dscanrep/), Aim@Shape repository, and other academic sources. Models include Dragon (202,520 polygons), Happy Buddha, Bunny (69,451 polygons), Gear, Dinosaur, Horse, Teeth, Elephant, VenusBody.

### 14.2 Download Status
These models are freely available as PLY files from Stanford's public repository. However, direct programmatic download was not performed in this implementation to keep the script self-contained and avoid large binary dependencies (~10-100 MB per model).

### 14.3 Substitute Used
The `generate_mesh()` function creates a random triangular mesh with configurable vertex and face counts. The index distributions differ from real scanned models, so the exact BPP values will vary from Table VIII. However, all algorithmic steps — RCS, classification, LZC/mMSB prediction, Huffman encoding, encryption, embedding, extraction, and decryption — execute on this synthetic mesh and produce verifiable correct results.

### 14.4 Justification
The correctness of the algorithm is content-independent: it depends only on the mathematical structure of vertex index differences, not on the specific geometry. The pass/fail tests in the demo (message recovery = PASS, face restoration = PASS) are valid correctness indicators regardless of mesh source.

### 14.5 Using Real Models
To run on real Stanford models:
```matlab
% Place bunny.ply in the same folder, then replace generate_mesh() with:
TR = stlread('bunny.stl');  % or use a PLY reader
V = TR.Points;
F = int32(TR.ConnectivityList - 1);  % 0-based indices
n = size(V,1);
```
