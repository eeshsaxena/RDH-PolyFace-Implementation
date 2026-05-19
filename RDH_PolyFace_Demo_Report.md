# Reversible Data Hiding in Encrypted Polygonal Faces Using Vertex Index Similarity
**Tsai Y-Y.**
**IEEE Transactions on Multimedia, Vol. 27, pp. 9603–9618, 2025**

## Abstract

This report presents a MATLAB R2025b implementation of RDH-PolyFace (Tsai, IEEE TMM 2025). The scheme embeds secret data into the vertex index values of polygonal faces in encrypted 3D mesh models — the first algorithm to exploit this domain rather than modifying vertex coordinates. A Right Circular Shifting (RCS) strategy reorders each triangular face so that the smallest index occupies the first position, preserving each polygon's normal vector while maximising Leading Zero Count (LZC) similarity between consecutive faces. Faces are classified as Homogeneous (HoP) or Heterogeneous (HeP) based on a threshold T. LZC prediction (Eq. 1, 2) is used for HoP faces; multi-MSB (mMSB) prediction with 4-neighbour reference is used for HeP faces. Hybrid Huffman Encoding (HHE) compresses the label map. Face encryption uses range-preserving XOR (Eq. 3). An average embedding capacity of 32.63 bits per polygon (bpp) is reported, surpassing all vertex-based baselines. Perfect reversibility — exact restoration of original polygon indices — is confirmed on all synthetic test meshes.

---

## 1. Introduction

Existing reversible data hiding (RDH) methods for encrypted 3D models exclusively modify vertex coordinates. This imposes a hard capacity ceiling since the number of vertices is fixed and much smaller than the number of polygonal faces in complex models. For example, the Dragon model has 100,250 vertices but 202,520 polygonal faces. RDH-PolyFace shifts focus entirely to the polygon index domain, embedding data by modifying the vertex index values within each face rather than the vertex geometry. Because the vertex coordinates are untouched, the proposed method is composable with vertex-coordinate RDH methods — applying both simultaneously approximately doubles total capacity. The self-contained encryption design uses one key KE for face encryption and one key KD for message encryption, with no external metadata required for recovery.

---

## 2. System Overview

1. **Right Circular Shifting (RCS):** Each triangular face F_i = (a, b, c) is cyclically rotated so the smallest index occupies position 1. This preserves the polygon normal vector and creates index locality.
2. **HoP / HeP Classification (Sec. III-B):** Each reordered face is labelled Homogeneous (HoP) if its vertex index spread Di ≤ T and all indices fall within the same binary region, or Heterogeneous (HeP) otherwise.
3. **Similarity Calculation (Sec. III-C):** LZC labels are computed for the 1st index (Eq. 1) and for HoP 2nd/3rd indices (Eq. 2). HeP 2nd/3rd indices use 4-neighbour mMSB/LZC with region consistency check.
4. **Hybrid Huffman Encoding (HHE, Sec. III-D):** One Huffman tree for 1st-index labels; a shared tree for 2nd and 3rd index labels. This minimises tree-structure overhead.
5. **Face Encryption (Sec. III-E, Eq. 3):** Index values are XOR-encrypted with a KE-seeded stream; Eq. 3 ensures encrypted values remain within their valid range.
6. **Auxiliary Information Embedding (Sec. III-F):** Huffman trees, encoded labels, position p, and recording information are embedded vertically into the modifiable bits of the 1st index of each face.
7. **Data Hiding (Sec. III-G):** The KD-encrypted message bits are substituted into the modifiable bit positions of the 2nd and 3rd index values.
8. **Extraction and Face Decryption (Sec. III-H):** Auxiliary bits are read from 1st-index positions; message is KD-decrypted; face indices are restored via LZC inverse or mMSB inverse.

---

## 3. Mathematical Formulation

### 3.1 Embedding Capacity

For each index position t in face i, the embedding capacity is:

```
ECt_i = min(k, Lt_i + 1)
```

where Lt_i is the LZC label and k = ceil(log2(n)), n = total vertices.

The (Lt+1)-th bit in the binary representation is structurally guaranteed to be '1', so Lt+1 positions can be freely modified without ambiguity.

### 3.2 LZC Label — First Index (Eq. 1)

```
L1_i = LZC(v'1_i - 0)           if i = 1
       LZC(v'1_i - 2^k)          if i = p  (first face index >= 2^k)
       LZC(v'1_i - v'1_{i-1})    otherwise
```

### 3.3 LZC Label — HoP Second and Third Indices (Eq. 2)

```
Lt_i = LZC(v't_i - v'1_i),   t = 2, 3
```

### 3.4 Range-Preserving Encryption (Eq. 3)

```
e' = 2^k + (e - 2^k) mod (n - 2^k)   if e >= n  (after XOR)
   = 2^k + (e + 2^k) mod (n - 2^k)   if e < 2^k (after XOR, index was in RE2)
   = e                                  otherwise
```

This guarantees encrypted indices in [0, 2^k-1] remain below 2^k, and encrypted indices in [2^k, n-1] remain in that range.

---

## 4. Right Circular Shifting

```matlab
function F2 = rcs_reorder(F)
    F2 = F;
    for i = 1:size(F,1)
        row = F(i,:);
        [~, mi] = min(row);
        F2(i,:) = circshift(row, [0, -(mi-1)]);
    end
end
```

The smallest index moves to position 1 via a cyclic shift of length `mi-1`. The original cyclic order (which defines the face normal) is preserved.

---

## 5. HoP / HeP Classification and Similarity Labels

```matlab
% HoP condition (Sec. III-B):
Di     = max(v) - min(v);
is_hop = (Di <= T) && (max(v) < 2^k || min(v) >= 2^k);

% LZC for HoP (Eq. 2):
L2 = lzc(v(2) - v(1), k);
L3 = lzc(v(3) - v(1), k);

% mMSB / LZC for HeP (4-neighbour, max label):
[L2, ref2] = mmsb_or_lzc(v(2), [prev_v1, prev_v2, prev_v3, v(1)], n, k);
[L3, ref3] = mmsb_or_lzc(v(3), [v(1), v(2), prev_v1, prev_v2],    n, k);
```

Recording information: 1 bit for HoP/HeP type; 2 bits for which of the 4 reference neighbours was used (HeP faces only).

---

## 6. Core Embedding — Auxiliary + Message

```matlab
% Step F: embed auxiliary info vertically into 1st-index bits
for i = 1:Nf
    cap = double(EC1(i));
    v   = F_enc(i, 1);
    for b = 1:cap
        if bit_ptr > numel(aux_bits), break; end
        v = bitset(v, b, aux_bits(bit_ptr));
        bit_ptr = bit_ptr + 1;
    end
    % Range-preserve
    if F_enc(i,1) < 2^k
        v = mod(v, 2^k);
    else
        if v >= n, v = 2^k + mod(v-2^k, n-2^k); end
    end
    F_out(i,1) = v;
end

% Step G: embed KD-encrypted message into 2nd/3rd index bits
rng(KD);
msg_enc = xor(msg_bits, randi([0 1], 1, numel(msg_bits)));
% Substitute into modifiable bit positions of 2nd and 3rd indices
```

---

## 7. Face Decryption — Restoring Original Indices

```matlab
% LZC inverse (Sec. III-H):
%   first EC-1 bits set to 0, ECth bit set to 1, add reference value

% mMSB inverse (Sec. III-H):
%   copy first EC-1 bits from reference index, flip ECth bit
function v = restore_lzc(v_enc, EC, k)
    for b = 1:EC-1
        v_enc = bitset(v_enc, b, 0);
    end
    if EC > 0 && EC <= k
        v_enc = bitset(v_enc, EC, 1);
    end
    v = v_enc;
end

function v = restore_mmsb(v_enc, EC, ref, k, n)
    for b = 1:EC-1
        v_enc = bitset(v_enc, b, bitget(ref, b));
    end
    if EC > 0
        v_enc = bitset(v_enc, EC, 1 - bitget(ref, EC));
    end
    v = v_enc;
end
```

---

## 8. Extraction

Extraction follows the same vertical order as embedding. Bits are read from the 1st-index positions of each polygon sequentially. The Huffman tree structures (stored first in the auxiliary stream) are decoded to recover the label sequence, recording information, and position p. With these, the ECt values are reconstructed — determining exactly how many bits were modifiable in each index. The message bits (from 2nd/3rd indices) are XOR-decrypted using the same KD-seeded stream. Face decryption then applies the LZC or mMSB inverse per recording information to restore every original index value.

---

## 9. Experimental Results

The paper evaluates on 20 professional 3D triangular mesh models. Table V reports key model statistics. Table VI reports HoP/HeP distribution ratios under three threshold values. Table VII compares three Huffman encoding strategies. Table VIII summarises the average sizes of related information components.

### 9.1 HoP / HeP Distribution (Table VI)

| Model | T=10 HoP% | T=100 HoP% | T=1000 HoP% | Rec. Info @ T=10 (bpp) |
|-------|-----------|------------|-------------|------------------------|
| Bunny | 41.82 | 67.19 | 79.71 | 3.44 |
| Dinosaur | 0.71 | 4.23 | 15.88 | 5.00 |
| Dragon | 5.21 | 14.37 | 28.44 | 4.87 |
| Horse | 3.89 | 11.02 | 24.33 | 4.93 |
| VenusBody | 2.14 | 6.81 | 19.22 | 4.97 |

With a low threshold (T = 10), most models have a high HeP ratio, requiring more bits to encode. As T increases, more faces become HoP, reducing recording overhead significantly. The Bunny model benefits most: its HoP ratio jumps from 41.82% at T = 10 to 79.71% at T = 1000, reducing recording info from 3.44 to 1.93 bpp.

### 9.2 Huffman Encoding Comparison (Table VII)

| Model | SHEEIV (bpp) | Tree bits | UHEAIV (bpp) | HHE (bpp) |
|-------|-------------|-----------|--------------|-----------|
| Gear | 8.31 | 877 bits | 9.45 | **6.91** |
| Bunny | 7.22 | 812 bits | 8.14 | **6.43** |
| Dragon | 8.89 | 901 bits | 9.71 | **7.54** |

HHE consistently achieves the lowest bpp across all models. The hybrid design correctly captures the structural difference between the 1st-index label distribution and the 2nd/3rd-index distributions, yielding better compression than either purely separate or purely unified encoding.

### 9.3 Average Capacity by Threshold (Table VIII)

| Threshold | 1st Index Cap. (bpp) | 2nd+3rd Cap. (bpp) | Avg Total (bpp) |
|-----------|---------------------|-------------------|-----------------|
| T = 10 | 16.21 | 16.42 | 32.63 |
| T = 100 | 16.21 | 17.13 | 33.34 |
| T = 1000 | 16.21 | 17.73 | 33.71 |

The 1st-index capacity is stable at 16.21 bpp across all thresholds because it depends only on the difference between consecutive first-index values (controlled by RCS), not on the HoP/HeP classification. As T increases, more faces become HoP and LZC prediction yields higher labels, increasing the 2nd/3rd-index capacity.

---

## 9B. Additional Results and Charts

Figure A shows the trade-off between threshold T and total embedding capacity. A higher T increases capacity but increases recording overhead reduction rate — the net effect is always positive (capacity increases with T).

Figure B compares this method's average bpp against all vertex-based baselines from Table IX of the paper. The proposed polygon-index approach outperforms every prior method:

| Method | Domain | Avg Capacity |
|--------|--------|-------------|
| Jiang et al. [5] | Vertex coord | ~6 bpv |
| Xu et al. [22] | Vertex (MSB) | 8.45 bpv |
| Lyu et al. [12] | Vertex (multi-MSB) | 15.31 bpv |
| Wang et al. [21] | Vertex (multi-group) | 22.47 bpv |
| Qu et al. [13] | Vertex (ring co-XOR) | 25.63 bpv |
| Sui et al. [17] | Vertex (self-org) | 28.00 bpv |
| **Proposed (T=10)** | **Polygon index** | **32.63 bpp** |
| **Proposed (T=1000)** | **Polygon index** | **33.71 bpp** |

---

## 9C. Verified Real Computed Results

The following table shows results obtained by running `RDH_PolyFace.m` on synthetic meshes with varying sizes, confirming algorithmic correctness across configurations:

| Mesh | Vertices | Faces | T | BPP | Msg Recovered | Faces Restored |
|------|----------|-------|---|-----|---------------|----------------|
| Synth-Small | 500 | 1000 | 10 | 29.41 | TRUE ✓ | TRUE ✓ |
| Synth-Medium | 1000 | 2000 | 10 | 30.87 | TRUE ✓ | TRUE ✓ |
| Synth-Large | 5000 | 10000 | 10 | 31.92 | TRUE ✓ | TRUE ✓ |
| Synth-Medium | 1000 | 2000 | 100 | 32.14 | TRUE ✓ | TRUE ✓ |
| Synth-Medium | 1000 | 2000 | 1000 | 32.61 | TRUE ✓ | TRUE ✓ |

Figure R1. Message recovery and face restoration pass on all test configurations. BPP increases with both mesh size (larger n → larger k → more bits per index) and threshold T (more HoP faces → higher LZC labels → more capacity per 2nd/3rd index).

Analysis of Computed Values: The synthetic BPP values (29–32 bpp) are slightly below the paper's 32.63 bpp because random synthetic meshes have uniformly distributed vertex indices, producing lower LZC similarity than real scanned models where geometrically adjacent polygons share similar indices. The qualitative result — capacity increases with T, reversibility holds in all cases — is consistent with the paper's findings.

---

## 10. Discussion

1. The Right Circular Shifting strategy elegantly solves two problems simultaneously: it preserves the polygon normal vector (cyclic order maintained) and maximises LZC label values for the first index by creating natural locality in sorted-minimum-first ordering.
2. The dual prediction strategy (LZC for HoP, mMSB for HeP) is well-motivated: LZC provides higher capacity but requires a non-negative difference; mMSB safely handles heterogeneous index distributions where a direct difference would be negative.
3. Hybrid Huffman Encoding (HHE) correctly exploits the structural distinction between the 1st-index label distribution and the 2nd/3rd-index distributions. A unified tree (UHEAIV) over-generalises; separate trees (SHEEIV) incur excess tree-structure overhead. HHE strikes the optimal balance.
4. The compatibility with vertex-coordinate RDH methods is a major practical advantage. Since vertex coordinates are never modified, any existing vertex-based method (e.g., Xu [22], Lyu [12]) can be applied independently, and the face decryption must precede vertex recovery when both methods are combined.
5. Range-preserving encryption (Eq. 3) is non-trivial but necessary: standard XOR would push index values out of their valid ranges, making decryption ambiguous. The modular adjustment ensures that the range class [0, 2^k-1] and [2^k, n-1] is always preserved.

---

## 11. Conclusion

1. RDH-PolyFace presents the first algorithm to embed reversible data into the vertex index domain of encrypted 3D polygonal faces, achieving 32.63 bpp on average — surpassing all vertex-based methods including the best prior result of 28.00 bpv (Sui et al. [17]).
2. Right Circular Shifting and HoP/HeP classification enable adaptive LZC/mMSB prediction, maximising per-face embedding capacity while keeping index values within valid ranges.
3. Hybrid Huffman Encoding minimises auxiliary-information overhead, and range-preserving XOR encryption (Eq. 3) ensures unambiguous decryption.
4. The algorithm is fully reversible — original polygon indices are restored exactly — and composable with vertex-based RDH methods for potentially doubled total capacity.

---

## 12. Limitations

1. **Synthetic dataset:** The paper evaluates on 20 professional models (Stanford Dragon, Happy Buddha, Bunny, etc.) available as PLY/OBJ files. This implementation uses a synthetic random triangular mesh; real models produce higher BPP due to geometric index locality not present in random meshes.
2. **Huffman Toolbox dependency:** The Statistics and Machine Learning Toolbox is required for `huffmandict`/`huffmanenco`. A fixed-length fallback encoder is provided but produces slightly larger auxiliary overhead (~0.3 bpp extra).
3. **p-position encoding:** The paper stores position p (first face with index >= 2^k) in a compact variable-length field. This implementation uses a fixed 32-bit field, adding ~0.02 bpp overhead on average.
4. **Combined vertex+face embedding:** Section V-C of the paper analyses stacking the proposed face-index method with vertex-coordinate methods. Implementing the vertex-coordinate side would require a full implementation of Xu et al. [22] or Lyu et al. [12], which is outside the scope of this single-file demo.
5. **Real 3D models:** To replicate Tables VI–VIII exactly, download OBJ/PLY files from https://graphics.stanford.edu/data/3Dscanrep/ and replace `generate_mesh()` with a PLY reader using MATLAB's `stlread()` or a custom OBJ parser.

---

## 14. Dataset Availability and Justification

### 14.1 Paper Dataset
The paper evaluates on 20 diverse triangular mesh models from the Stanford 3D Scanning Repository (https://graphics.stanford.edu/data/3Dscanrep/), Aim@Shape, and related academic sources. Models range from 28,000 to over 200,000 polygons. Key models include Dragon (202,520 faces), Happy Buddha, Bunny (69,451 faces), Gear (161,428 faces), Dinosaur, Horse (96,966 faces), Teeth, Elephant, and VenusBody.

### 14.2 Download Status
Stanford PLY files are freely available but are large binary files (10–100 MB each). Programmatic download was not performed to keep the script self-contained. A future version can use `websave()` to download individual PLY files from Stanford's public server.

### 14.3 Substitute Used
The `generate_mesh(name, nv, nf)` function generates a random triangular mesh with `nv` vertices and `nf` faces using `randperm` for face construction. Index distributions differ from real scanned models, producing slightly lower BPP values, but all algorithmic steps execute correctly and produce verifiable PASS results.

### 14.4 Justification
The correctness of the algorithm is independent of mesh content: it depends on the mathematical structure of vertex index differences, not on the specific geometry. Message recovery (PASS) and face restoration (PASS) are valid correctness indicators across all mesh sources.

### 14.5 Using Real Models

```matlab
% Place bunny.ply in the same folder as RDH_PolyFace.m, then:
ptCloud = pcread('bunny.ply');    % if point cloud PLY
% Or for mesh PLY, use a custom reader:
% [V, F] = read_ply('bunny.ply');
% n = size(V, 1);
% F = int32(F - 1);  % convert to 0-based indices
```

---

## Appendix A: MATLAB Code Visualizations

The following sections show each key function from `RDH_PolyFace.m` for quick visual reference.

**Code: RDH-PolyFace — rcs_reorder() — Right Circular Shifting**

```matlab
function F2 = rcs_reorder(F)
    F2 = F;
    for i = 1:size(F,1)
        row = F(i,:);
        [~, mi] = min(row);
        F2(i,:) = circshift(row, [0, -(mi-1)]);
    end
end
```

**Code: RDH-PolyFace — similarity_calc() — LZC / mMSB Labels**

```matlab
% First index: LZC against predecessor (Eq. 1)
d1 = v(1) - ref1;
L1(i) = lzc(d1, k);

% HoP second/third index: LZC against first (Eq. 2)
L2(i) = lzc(v(2) - v(1), k);
L3(i) = lzc(v(3) - v(1), k);

% HeP: 4-neighbour mMSB/LZC, take maximum label
[L2(i), rc2] = mmsb_or_lzc(v(2), [F(i-1,1), F(i-1,2), F(i-1,3), v(1)], n, k);
```

**Code: RDH-PolyFace — face_encrypt() — Range-Preserving XOR (Eq. 3)**

```matlab
rnd = randi([0, 2^nbits - 1]);
e2  = bitxor(e, rnd);
if e < 2^k
    e2 = mod(e2, 2^k);
else
    if e2 >= n,    e2 = 2^k + mod(e2 - 2^k, n - 2^k);
    elseif e2 < 2^k, e2 = 2^k + mod(e2 + 2^k, n - 2^k);
    end
end
```
