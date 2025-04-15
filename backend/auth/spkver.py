import os
import glob
import itertools

import numpy as np

import torch.nn.functional as F
import torchaudio

from speechbrain.inference.speaker import SpeakerRecognition, EncoderClassifier

from utils import cosine_similarity

verification = SpeakerRecognition.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb",
    savedir="pretrained_models/spkrec-ecapa-voxceleb"
)
classifier = EncoderClassifier.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb", 
    savedir="pretrained_models/spkrec-ecapa-voxceleb"
)

speaker_embeddings = {}

data_root = "data/"
speaker_dirs = sorted(os.listdir(data_root))

for spk_id in speaker_dirs:
    spk_path = os.path.join(data_root, spk_id)
    if not os.path.isdir(spk_path):
        continue  # 혹시 폴더가 아니면 스킵

    wav_files = glob.glob(os.path.join(spk_path, "*.wav"))
    embeddings = []
    for wav_path in wav_files:
        signal, fs = torchaudio.load(wav_path)
        embedding = classifier.encode_batch(signal)
        emb = embedding[0, 0, :]
        
        embeddings.append(emb)
    speaker_embeddings[spk_id] = embeddings


genuine_scores = []

for spk_id, emb_list in speaker_embeddings.items():
    for emb1, emb2 in itertools.combinations(emb_list, 2):
        score = F.cosine_similarity(emb1, emb2, dim=0)
        genuine_scores.append(score)

impostor_scores = []

spk_ids = list(speaker_embeddings.keys())
for i in range(len(spk_ids)):
    for j in range(i + 1, len(spk_ids)):
        spk_a = spk_ids[i]
        spk_b = spk_ids[j]
        emb_list_a = speaker_embeddings[spk_a]
        emb_list_b = speaker_embeddings[spk_b]
        
        for emb1 in emb_list_a:
            for emb2 in emb_list_b:
                score = F.cosine_similarity(emb1, emb2, dim=0)
                impostor_scores.append(score)
                
labels = np.array([1]*len(genuine_scores) + [0]*len(impostor_scores))
scores = np.array(genuine_scores + impostor_scores)

sorted_scores = np.sort(scores)

best_eer = 1.0
best_thresh = None

# Genuine, Impostor 개수
num_genuine = np.sum(labels == 1)
num_impostor = np.sum(labels == 0)

for thresh in sorted_scores:
    # Genuine(1)인데 score < thresh이면 False Reject
    # Impostor(0)인데 score >= thresh이면 False Accept
    
    # Genuine 점수 중 threshold 미만 → False Reject(FR)
    FR = np.sum((labels == 1) & (scores < thresh))
    FRR = FR / num_genuine  # False Rejection Rate
    
    # Impostor 점수 중 threshold 이상 → False Accept(FA)
    FA = np.sum((labels == 0) & (scores >= thresh))
    FAR = FA / num_impostor  # False Acceptance Rate

    # FAR와 FRR이 같은 지점(또는 가장 비슷한 지점)
    if abs(FAR - FRR) < best_eer:
        best_eer = (FAR + FRR) / 2.0
        best_thresh = thresh

print(f"EER = {best_eer*100:.2f}%")
print(f"EER threshold = {best_thresh:.3f}")