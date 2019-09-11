# This script transcribes a wavefile sampled at 16 kHz, result will be stored in /transcription/one-best-hypothesis.txt
# This script is based on the blogpost by  Josh Meyer: http://jrmeyer.github.io/asr/2016/09/12/Using-built-GMM-model-Kaldi.html

#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh

echo "Input Audio Preparation"
rm -rf transcriptions

mkdir transcriptions

realpath ./inputaudio/*.wav > ./transcriptions/wavefilepaths.txt


echo "Creating the list of utterence IDs"

#Need to remove the hardcoding of 9 in next line.  The function is to extract the utterance id
cat ./transcriptions/wavefilepaths.txt | cut -d '/' -f 7 |cut -d '.' -f 1 > ./transcriptions/utt


echo "Creating the list of utterence IDs mapped to absolute file paths of wavefiles"


#Create wav.scp mapping from uttrence id to absolute wave file paths
paste ./transcriptions/utt ./transcriptions/wavefilepaths.txt > ./transcriptions/wav.scp

rm ./transcriptions/utt
rm ./transcriptions/wavefilepaths.txt

echo "=================COMPUTING MFCC====================="

#subtract-mean = true in the following line is equivalent to mean variance normalization during training

compute-mfcc-feats \
    --config=conf/mfcc.conf \
    --subtract-mean=true \
    scp:transcriptions/wav.scp \
    ark,scp:transcriptions/feats.ark,transcriptions/feats.scp 

add-deltas \
    scp:transcriptions/feats.scp \
    ark:transcriptions/delta-feats.ark



echo "GMM-HMM + FEATURE VECTOR ======> LATTICE"

gmm-latgen-faster \
    --word-symbol-table=exp/tri1/graph/words.txt \
    exp/tri1/final.mdl \
    exp/tri1/graph/HCLG.fst \
    ark:transcriptions/delta-feats.ark \
    ark,t:transcriptions/lattices.ark

echo "ONE BEST LATTICE"

lattice-best-path \
    --word-symbol-table=exp/tri1/graph/words.txt \
    ark:transcriptions/lattices.ark \
    ark,t:transcriptions/one-best.tra

echo "ONE BEST WORD SEQUENCE"

utils/int2sym.pl -f 2- \
    exp/tri1/graph/words.txt \
    transcriptions/one-best.tra \
    > transcriptions/one-best-hypothesis.txt