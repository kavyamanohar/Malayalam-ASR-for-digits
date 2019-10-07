# This script transcribes a wavefile sampled at 16 kHz, result will be stored in /transcription/one-best-hypothesis.txt
# This script is based on the blogpost by  Josh Meyer: http://jrmeyer.github.io/asr/2016/09/12/Using-built-GMM-model-Kaldi.html

#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh

echo "Input Audio Preparation"
rm -rf ./inputaudio/transcriptions

mkdir ./inputaudio/transcriptions

realpath ./inputaudio/*.wav > ./inputaudio/transcriptions/wavefilepaths.txt


echo "Creating the list of utterence IDs"

# The function is to extract the utterance id
cat ./inputaudio/transcriptions/wavefilepaths.txt | xargs -l basename -s .wav > ./inputaudio/transcriptions/utt


echo "Creating the list of utterence IDs mapped to absolute file paths of wavefiles"


#Create wav.scp mapping from uttrence id to absolute wave file paths
paste ./inputaudio/transcriptions/utt ./inputaudio/transcriptions/wavefilepaths.txt > ./inputaudio/transcriptions/wav.scp

rm ./inputaudio/transcriptions/utt
rm ./inputaudio/transcriptions/wavefilepaths.txt

echo "=================COMPUTING MFCC====================="

#subtract-mean = true in the following line is equivalent to mean variance normalization during training

compute-mfcc-feats \
    --config=conf/mfcc.conf \
    --subtract-mean=true \
    scp:./inputaudio/transcriptions/wav.scp \
    ark,scp:./inputaudio/transcriptions/feats.ark,./inputaudio/transcriptions/feats.scp 

add-deltas \
    scp:./inputaudio/transcriptions/feats.scp \
    ark:./inputaudio/transcriptions/delta-feats.ark



echo "GMM-HMM + FEATURE VECTOR ======> LATTICE"

# Use appropriate decoding graphs: mono, tri1, tri_lda, tri_sat. But you have to make
# sure the audio processing should have been done accordingly. 

usegraph=tri1


gmm-latgen-faster \
    --word-symbol-table=exp/$usegraph/graph/words.txt \
    exp/$usegraph/final.mdl \
    exp/$usegraph/graph/HCLG.fst \
    ark:./inputaudio/transcriptions/delta-feats.ark \
    ark,t:./inputaudio/transcriptions/lattices.ark

echo "ONE BEST LATTICE"

lattice-best-path \
    --word-symbol-table=exp/$usegraph/graph/words.txt \
    ark:./inputaudio/transcriptions/lattices.ark \
    ark,t:./inputaudio/transcriptions/one-best.tra

echo "ONE BEST WORD SEQUENCE"

utils/int2sym.pl -f 2- \
    exp/$usegraph/graph/words.txt \
    ./inputaudio/transcriptions/one-best.tra \
    > ./inputaudio/transcriptions/one-best-hypothesis.txt