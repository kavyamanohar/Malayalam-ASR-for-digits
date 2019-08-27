#set-up for single machine or cluster based execution
#. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


#Remove existing data
rm -rf data
rm -rf exp
rm -rf mfcc

#Create fresh data files
mkdir data
mkdir data/train

#Read path of wave files and store it as a temporary file wavefilepaths.txt 
realpath ./waves/train/*.wav > ./data/train/wavefilepaths.txt

#Need to remove the hardcoding of 8 in next line.  The function is to extract the utterance id
cat ./data/train/wavefilepaths.txt | cut -d '/' -f 8 |cut -d '.' -f 1 > ./data/train/utt

#Create wav.scp mapping from uttrence id to absolute wave file paths
paste ./data/train/utt ./data/train/wavefilepaths.txt > ./data/train/wav.scp

#Create speaker id list
cat ./data/train/utt | cut -d 'F' -f 1 > ./data/train/spk

#Create utt2spk
paste ./data/train/utt ./data/train/spk > ./data/train/utt2spk


#Create spk2utt
./utils/utt2spk_to_spk2utt.pl ./data/train/utt2spk > ./data/train/spk2utt

rm ./data/train/wavefilepaths.txt

#Create feature vectors
./steps/make_mfcc.sh --nj 1 data/train exp/make_mfcc/train mfcc

#Create Mean Variance Tuning
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/test mfcc
