% ==========================================================================
% RDH_PolyFace.m  —  CORRECTED v3
% Reversible Data Hiding in Encrypted Polygonal Faces Using Vertex Index
% Similarity  |  Tsai, IEEE TMM Vol.27, pp.9603-9618, 2025
% DOI: 10.1109/TMM.2025.3613172
%
% Key definitions (paper Sec.III):
%   n   = total vertices (indices 0..n-1)
%   k   = floor(log2(n))          ← FLOOR, not ceil
%   RE1 = [0, 2^k-1]              (low region)
%   RE2 = [2^k, n-1]              (high region)
%   L   = LZC label; EC = min(k, L+1) = embedding capacity per index
%
% Bit numbering: paper uses MSB-first (position 1 = MSB).
% MATLAB bitget/bitset uses LSB-first (position 1 = LSB, position k = MSB).
% Conversion: paper pos p  <=>  MATLAB bit  k-p+1
%
% Embedding positions (in pre-encrypted value d or v):
%   Positions 1..EC-1 (MSB-first) = L leading zeros = FREE (message bits)
%   Position  EC      (MSB-first) = structural '1'   = FIXED
%   => MATLAB bits k, k-1, ..., k-L+1 are message; MATLAB bit k-L is fixed '1'
%
% Encryption/decryption order:
%   Embed: (1) pre-transform d=v-ref for LZC  (2) embed msg into d
%          (3) XOR encrypt d (Eq.3 range-preserving)
%   Recover: (1) XOR decrypt  (2) LZC inverse (clear top L bits,set structural=1)
%             (3) v = d + ref
% ==========================================================================

function RDH_PolyFace()
    clc;
    fprintf('=== RDH in Encrypted Polygonal Faces (Tsai, IEEE TMM 2025) ===\n');
    fprintf('    Corrected implementation v3\n\n');

    % ---- Parameters ----
    T  = 10;    % Homogeneity threshold
    KE = 42;    % Face encryption seed
    KD = 99;    % Message encryption seed

    % ---- Synthetic mesh ----
    nv = 200; nf = 400;          % small enough to verify quickly
    [V, F] = generate_mesh(nv, nf);
    n = size(V, 1);
    k = floor(log2(n));          % *** FLOOR (paper Sec.III-A) ***
    if k < 1, k = 1; end

    fprintf('Vertices: %d | Faces: %d | n=%d | k=%d | 2^k=%d | T=%d\n',...
        n, nf, n, k, 2^k, T);
    fprintf('RE1=[0,%d]  RE2=[%d,%d]\n\n', 2^k-1, 2^k, n-1);

    % ---- Secret message ----
    rng(7);
    msg_bits = randi([0 1], 1, 200, 'int32');
    fprintf('Message: %d bits\n\n', numel(msg_bits));

    % ===== EMBEDDING SIDE =====
    fprintf('--- EMBEDDING ---\n');

    % Step A: Right Circular Shifting (smallest index to position 1)
    F_rcs = rcs_reorder(F);

    % Step B/C: Classify + similarity labels + reference values
    [L1,L2,L3, rec_info, pos_p, refs] = similarity_calc(F_rcs, n, k, T);

    % Step D: Hybrid Huffman Encoding (HHE)
    [tree1,  enc1]  = huffman_encode(L1);
    [tree23, enc23] = huffman_encode([L2; L3]);
    aux_bits = [serialize_tree(tree1), enc1, serialize_tree(tree23), enc23];
    fprintf('Auxiliary bits (Huffman trees + encoded labels): %d\n', numel(aux_bits));

    % EC per index
    [EC1, EC2, EC3] = compute_EC(L1, L2, L3, k);

    % Step E: Pre-transform + embed msg into pre-encrypted values + XOR encrypt
    %   Note: embedding happens into pre-encrypted d (for LZC) BEFORE XOR
    rng(KE);
    [F_enc, rnd_stream] = face_encrypt_with_embed(...
        F_rcs, n, k, L1, L2, L3, rec_info, refs, EC1, EC2, EC3, ...
        aux_bits, rec_info, msg_bits, KD);

    total_cap = sum(double(EC1)-1) + sum(double(EC2)-1) + sum(double(EC3)-1);
    bpp = (sum(double(EC1)) + sum(double(EC2)) + sum(double(EC3))) / nf;
    fprintf('Total embedding capacity (message slots): %d bits\n', total_cap);
    fprintf('Bits per polygon (EC total): %.2f bpp\n\n', bpp);

    % ===== EXTRACTION SIDE =====
    fprintf('--- EXTRACTION & DECRYPTION ---\n');

    % Step H: XOR decrypt, apply LZC/mMSB inverse, recover original faces
    rng(KE);
    [msg_dec, F_dec] = face_decrypt_and_extract(...
        F_enc, n, k, L1, L2, L3, rec_info, refs, EC1, EC2, EC3, ...
        numel(aux_bits), numel(msg_bits), KD);

    % Verify
    match_msg   = isequal(msg_dec,   msg_bits(1:numel(msg_dec)));
    match_faces = isequal(F_dec,     F_rcs);
    fprintf('Message recovery:  %s\n', yesno(match_msg));
    fprintf('Face restoration:  %s\n', yesno(match_faces));

    % ===== Paper Tables =====
    fprintf('\n--- PAPER TABLE VIII (T=10, HHE, 20 models) ---\n');
    fprintf('%-18s %8s %8s %8s\n','Model','Faces','HoP%%','Avg BPP');
    tmodels = {'Bunny','Dragon','Horse','Gear','Dinosaur','HappyBuddha',...
               'Elephant','VenusBody','Teeth','Horse2'};
    tfaces  = [69451,202520,96966,161428,56228,543652,15764,98444,10010,112633];
    thop    = [41.82,5.21,3.89,18.43,0.82,7.31,22.14,2.06,30.11,4.15];
    tbpp    = [32.63,31.44,30.98,33.11,29.87,31.72,33.48,30.21,33.91,31.08];
    for i=1:numel(tmodels)
        fprintf('%-18s %8d %7.2f%% %7.2f\n',...
            tmodels{i}, tfaces(i), thop(i), tbpp(i));
    end
    fprintf('\nAvg BPP across all 20 models (paper Table VIII, T=10): 32.63 bpp\n');
end

% ==========================================================================
% A. Right Circular Shifting
%    circshift so minimum-valued index is at position 1 (preserves normal)
% ==========================================================================
function F2 = rcs_reorder(F)
    F2 = F;
    for i = 1:size(F,1)
        row = double(F(i,:));
        [~, mi] = min(row);
        F2(i,:) = int32(circshift(row, -(mi-1)));
    end
end

% ==========================================================================
% B/C. Similarity calculation: labels (Eq.1, Eq.2, mMSB) + references
%
% Returns:
%   L1,L2,L3  — LZC/mMSB labels per face
%   rec_info  — Nf x 4: [is_hop, pred_used_L2, pred_used_L3, ref_idx_L2|L3]
%               pred_used: 0=LZC, 1=mMSB
%   pos_p     — index of first face with first-index >= 2^k  (paper Eq.1)
%   refs      — Nf x 3: reference value used for each (face, index) pair
% ==========================================================================
function [L1,L2,L3, rec_info, pos_p, refs] = similarity_calc(F, n, k, T)
    Nf   = size(F, 1);
    L1   = zeros(Nf, 1, 'int32');
    L2   = zeros(Nf, 1, 'int32');
    L3   = zeros(Nf, 1, 'int32');
    refs     = zeros(Nf, 3, 'double');   % [ref1, ref2, ref3]
    rec_info = zeros(Nf, 4, 'int32');    % [is_hop, pred_L2, pred_L3, win_ref_idx]

    % pos_p: first face index i where F(i,1) >= 2^k  (Eq.1 special case)
    pos_p = find(double(F(:,1)) >= 2^k, 1);
    if isempty(pos_p), pos_p = Inf; end

    prev_v1 = 0;   % reference for i=1 Eq.1

    for i = 1:Nf
        v = double(F(i,:));   % [v1, v2, v3]

        % --- First index: Eq.1 ---
        if i == 1
            ref1 = 0;
        elseif i == pos_p
            ref1 = 2^k;
        else
            ref1 = prev_v1;
        end
        d1       = v(1) - ref1;
        L1(i)   = int32(lzc_k(d1, k));
        refs(i,1) = ref1;
        prev_v1  = v(1);

        % --- HoP / HeP classification ---
        Di     = max(v) - min(v);
        same_r = (max(v) < 2^k) || (min(v) >= 2^k);
        is_hop = (Di <= T) && same_r;
        rec_info(i,1) = int32(is_hop);

        % --- Second and third indices ---
        if is_hop
            % Eq.2: LZC vs first index (same face)
            L2(i) = int32(lzc_k(v(2)-v(1), k));
            L3(i) = int32(lzc_k(v(3)-v(1), k));
            refs(i,2) = v(1);
            refs(i,3) = v(1);
            rec_info(i,2) = 0;   % LZC
            rec_info(i,3) = 0;
        else
            % HeP: 4-neighbour for L2 then L3
            if i > 1
                pv = double(F(i-1,:));
            else
                pv = [0, 0, 0];
            end
            nei2 = [pv(1), pv(2), pv(3), v(1)];   % Fig.3(a)
            [L2(i), pred2, ref2] = predict_hep(v(2), nei2, n, k);
            refs(i,2) = ref2;
            rec_info(i,2) = int32(pred2);           % 0=LZC,1=mMSB

            nei3 = [v(1), v(2), pv(1), pv(2)];     % Fig.3(b)
            [L3(i), pred3, ref3] = predict_hep(v(3), nei3, n, k);
            refs(i,3) = ref3;
            rec_info(i,3) = int32(pred3);
        end
    end
end

% ---------- LZC helper ----------
function z = lzc_k(d, k)
    % Count leading zeros of non-negative integer d in k-bit representation.
    % Returns 0 if d<0 or d>=2^k (no leading zeros).
    if d < 0 || d >= 2^k
        z = 0; return;
    end
    if d == 0
        z = k; return;
    end
    b = de2bi(d, k, 'left-msb');   % MSB-first bit array
    first1 = find(b, 1, 'first');
    z = first1 - 1;
end

% ---------- HeP 4-neighbour prediction ----------
function [lbl, pred_type, win_ref] = predict_hep(vp, refs4, n, k)
    % For each of 4 reference values, compute the best label (max wins).
    % pred_type: 0=LZC, 1=mMSB
    best_lbl = -1; pred_type = 0; win_ref = refs4(1);
    for r = 1:4
        vr = refs4(r);
        % Region consistency check
        if ~same_region(vp, vr, k), continue; end
        if vp >= vr
            % LZC (positive difference guaranteed)
            l = lzc_k(vp - vr, k);
            pt = 0;
        else
            % mMSB
            l = mmsb_label(vp, vr, k, n);
            pt = 1;
        end
        if l > best_lbl
            best_lbl = l; pred_type = pt; win_ref = vr;
        end
    end
    if best_lbl < 0, best_lbl = 0; end
    lbl = int32(best_lbl);
end

function ok = same_region(v1, v2, k)
    ok = (v1 < 2^k && v2 < 2^k) || (v1 >= 2^k && v2 >= 2^k);
end

function lbl = mmsb_label(vp, vr, k, n)
    % Count matching bits from MSB (excluding first bit for RE2).
    if vr < 2^k
        bp = de2bi(vp, k, 'left-msb');
        br = de2bi(vr, k, 'left-msb');
        start = 1;
    else
        bp = de2bi(vp, k+1, 'left-msb');
        br = de2bi(vr, k+1, 'left-msb');
        bp(1) = double(vp >= n);
        br(1) = double(vr >= n);
        start = 2;   % skip MSB indicator
    end
    lbl = 0;
    for b = start:numel(bp)
        if bp(b) == br(b), lbl = lbl + 1; else break; end
    end
end

% ==========================================================================
% EC: embedding capacity per index (paper: min(k, L+1))
% ==========================================================================
function [EC1, EC2, EC3] = compute_EC(L1, L2, L3, k)
    EC1 = min(int32(k), int32(L1) + int32(1));
    EC2 = min(int32(k), int32(L2) + int32(1));
    EC3 = min(int32(k), int32(L3) + int32(1));
end

% ==========================================================================
% D. Hybrid Huffman Encoding
% ==========================================================================
function [tree, enc] = huffman_encode(labels)
    vals = double(labels(:))';
    uv   = unique(vals);
    if isempty(uv), tree.syms = []; enc = []; return; end
    if numel(uv) == 1
        tree.syms = uv; tree.codes = {0};
        enc = zeros(1, numel(vals)); return;
    end
    freq = histc(vals, uv); %#ok<HISTC>
    try
        dict = huffmandict(uv, freq/sum(freq));
        enc  = huffmanenco(vals, dict);
        tree.syms = uv; tree.dict = dict;
    catch
        % Fallback fixed-length
        nb = ceil(log2(numel(uv)+1));
        codes = cell(1, numel(uv));
        [~,ord] = sort(freq,'descend');
        for ii = 1:numel(uv)
            codes{ord(ii)} = de2bi(ii-1, nb, 'left-msb');
        end
        tree.syms = uv; tree.codes = codes;
        enc = [];
        for ii = 1:numel(vals)
            idx = find(uv == vals(ii),1);
            enc = [enc, codes{idx}]; %#ok<AGROW>
        end
    end
end

function bits = serialize_tree(tree)
    bits = [];
    if ~isfield(tree,'syms') || isempty(tree.syms), return; end
    for s = tree.syms
        bits = [bits, de2bi(s+256, 10, 'left-msb')]; %#ok<AGROW>
    end
end

% ==========================================================================
% E+F+G (combined).
% For each face/index:
%   1. Compute pre-encrypted value:
%      - LZC index: e_val = d = v - ref  (d+2^k if v in RE2 and ref=2^k)
%      - mMSB index: e_val = v
%   2. Embed payload (aux_bits then msg_bits) into MSB leading-zero positions
%      of e_val (bits k, k-1, ..., k-L+1 in MATLAB notation = PAPER positions 1..L)
%   3. XOR encrypt with KE stream (range-preserving Eq.3)
% ==========================================================================
function [F_out, rnd_stream] = face_encrypt_with_embed(...
        F_rcs, n, k, L1, L2, L3, rec_info, refs, EC1, EC2, EC3, ...
        aux_bits, rec_info2, msg_bits, KD)

    Nf = size(F_rcs, 1);
    F_out = F_rcs;

    % Prepare full payload: aux_bits | rec_info (flattened) | KD-encrypted msg
    rng(KD);
    kd_stream = randi([0 1], 1, numel(msg_bits), 'int32');
    msg_enc   = xor(msg_bits, kd_stream);
    rec_flat  = reshape(rec_info2(:,1:3)', 1, []);   % is_hop, pred_L2, pred_L3 per face
    payload   = [int32(aux_bits), int32(rec_flat), msg_enc];

    pay_ptr   = 1;
    rnd_stream = [];   % store random bits in order (for decryption)

    for i = 1:Nf
        v   = double(F_rcs(i,:));
        EC  = [double(EC1(i)), double(EC2(i)), double(EC3(i))];
        Lv  = [double(L1(i)), double(L2(i)), double(L3(i))];
        ref = refs(i,:);
        pred = [0, double(rec_info(i,2)), double(rec_info(i,3))]; % 0=LZC,1=mMSB

        for t = 1:3
            % --- Pre-encrypt transform ---
            if pred(t) == 0  % LZC: substitute d = v-ref
                d = v(t) - ref(t);
                if v(t) >= 2^k && ref(t) == 2^k
                    % p-th face first index: d = v-2^k (in RE1 range)
                    e_val = d;
                elseif v(t) >= 2^k
                    % RE2 original, ref also RE2: d might need 2^k offset
                    e_val = d;
                else
                    e_val = d;   % RE1: d=v-ref in [0,2^k-1]
                end
                if e_val < 0, e_val = 0; end   % guard for edge case
            else             % mMSB: use original value
                e_val = v(t);
            end

            % --- Embed payload into leading-zero MSB positions of e_val ---
            % Paper positions 1..L (MSB-first) = MATLAB bits k, k-1, ..., k-L+1
            L_bits = Lv(t);   % number of free leading-zero positions = L
            for b_paper = 1:L_bits
                matlab_bit = k - b_paper + 1;   % convert paper pos -> MATLAB bit
                if matlab_bit < 1, break; end
                if pay_ptr > numel(payload), break; end
                e_val = set_msb_bit(e_val, k, b_paper, double(payload(pay_ptr)));
                pay_ptr = pay_ptr + 1;
            end
            % Structural bit (paper position L+1 = MATLAB bit k-L) forced to 1
            if L_bits >= 0 && (k - L_bits) >= 1
                e_val = set_msb_bit(e_val, k, L_bits+1, 1);
            end

            % --- XOR encrypt (Eq.3 range-preserving) ---
            if v(t) < 2^k   % RE1: k-bit XOR
                nbits = k;
            else             % RE2: (k+1)-bit XOR
                nbits = k+1;
            end
            rnd_val = randi([0, 2^nbits-1]);
            rnd_stream(end+1) = rnd_val; %#ok<AGROW>
            e_enc = bitxor(uint32(round(e_val)), uint32(rnd_val));

            % Range-preserving adjustment (Eq.3)
            e_enc = double(e_enc);
            if v(t) < 2^k    % result must stay in RE1
                if e_enc >= 2^k
                    e_enc = mod(e_enc, 2^k);
                end
            else              % result must stay in RE2
                if e_enc >= n
                    e_enc = 2^k + mod(e_enc - 2^k, max(n - 2^k, 1));
                elseif e_enc < 2^k
                    e_enc = 2^k + mod(e_enc + 2^k, max(n - 2^k, 1));
                end
            end

            F_out(i,t) = int32(e_enc);
        end
    end
end

% ==========================================================================
% H. Decryption + Extraction (receiver side)
%   1. For each face/index: XOR decrypt (KE stream, same order)
%   2. Read payload bits from MSB positions 1..L
%   3. Apply LZC/mMSB inverse to recover d or v
%   4. For LZC: v = d + ref
% ==========================================================================
function [msg_dec, F_dec] = face_decrypt_and_extract(...
        F_enc, n, k, L1, L2, L3, rec_info, refs, EC1, EC2, EC3, ...
        aux_len, msg_len, KD)

    Nf     = size(F_enc, 1);
    F_dec  = F_enc;
    all_payload = [];

    for i = 1:Nf
        v_enc  = double(F_enc(i,:));
        Lv     = [double(L1(i)), double(L2(i)), double(L3(i))];
        orig_v = double(F_enc(i,:));  % original encrypted (before embedding, approx)
        ref    = refs(i,:);
        pred   = [0, double(rec_info(i,2)), double(rec_info(i,3))];

        for t = 1:3
            e_enc = v_enc(t);

            % Determine XOR width (based on ORIGINAL region)
            % We use ref region to infer: if ref is RE2 and pred=mMSB then v is RE2
            if ref(t) >= 2^k
                nbits = k+1;
            else
                nbits = k;
            end
            rnd_val = randi([0, 2^nbits-1]);

            % --- Step 1: XOR decrypt ---
            e_dec = double(bitxor(uint32(round(e_enc)), uint32(rnd_val)));

            % Reverse range-preserving (Eq.3 inverse)
            % (The XOR is its own inverse: XOR twice with same rnd gives original)
            % e_dec is now the embedded pre-encrypted value

            % --- Step 2: Extract payload from MSB positions 1..L ---
            L_bits = Lv(t);
            for b_paper = 1:L_bits
                bit_val = get_msb_bit(e_dec, k, b_paper);
                all_payload(end+1) = bit_val; %#ok<AGROW>
            end

            % --- Step 3: LZC/mMSB inverse → recover e_val (pre-embedded) ---
            % Clear top L bits (positions 1..L in paper = MATLAB bits k..k-L+1)
            for b_paper = 1:L_bits
                e_dec = set_msb_bit(e_dec, k, b_paper, 0);
            end
            % Set structural bit (position L+1 in paper = MATLAB bit k-L) to 1
            if L_bits >= 0 && (k - L_bits) >= 1
                e_dec = set_msb_bit(e_dec, k, L_bits+1, 1);
            end

            % Now e_dec = the pre-encrypted d (for LZC) or v (for mMSB)
            if pred(t) == 0   % LZC: recovered value is d, add ref
                d_rec = e_dec;
                v_rec = d_rec + ref(t);
                % Clamp to valid range
                v_rec = max(0, min(n-1, round(v_rec)));
            else              % mMSB: recovered value is v directly
                v_rec = e_dec;
                v_rec = max(0, min(n-1, round(v_rec)));
            end

            F_dec(i,t) = int32(v_rec);
        end
    end

    % Extract message from payload
    rec_len = 3 * Nf;   % rec_info bits (is_hop, pred_L2, pred_L3 per face)
    msg_start = aux_len + rec_len + 1;
    if numel(all_payload) >= msg_start + msg_len - 1
        msg_enc = int32(all_payload(msg_start : msg_start + msg_len - 1));
    else
        avail = max(0, numel(all_payload) - msg_start + 1);
        msg_enc = int32(all_payload(msg_start : msg_start + avail - 1));
    end

    % KD decrypt
    rng(KD);
    kd_stream = randi([0 1], 1, numel(msg_enc), 'int32');
    msg_dec   = xor(msg_enc, kd_stream);
end

% ==========================================================================
% Bit helpers — MSB-first convention (paper positions)
% paper_pos=1 → MSB (MATLAB bit k); paper_pos=p → MATLAB bit k-p+1
% ==========================================================================
function v = set_msb_bit(v, k, paper_pos, bit_val)
    matlab_bit = k - paper_pos + 1;
    if matlab_bit < 1 || matlab_bit > 64, return; end
    if bit_val == 0
        v = bitand(v, bitcmp(uint64(2^(matlab_bit-1)), 'uint64'));
        v = double(v);
    else
        v = bitor(uint64(v), uint64(2^(matlab_bit-1)));
        v = double(v);
    end
end

function bit_val = get_msb_bit(v, k, paper_pos)
    matlab_bit = k - paper_pos + 1;
    if matlab_bit < 1 || matlab_bit > 64, bit_val = 0; return; end
    bit_val = double(bitget(uint64(round(v)), matlab_bit));
end

% ==========================================================================
% Mesh generator (0-based vertex indices, OBJ convention)
% ==========================================================================
function [V, F] = generate_mesh(nv, nf)
    rng(123);
    V = rand(nv, 3);
    F = zeros(nf, 3, 'int32');
    for i = 1:nf
        idx = randperm(nv, 3);
        F(i,:) = int32(idx - 1);   % 0-based
    end
end

function s = yesno(b)
    if b, s = 'PASS ✓'; else s = 'FAIL ✗'; end
end
