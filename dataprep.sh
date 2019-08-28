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

echo ============================================================================
echo "                  Preparing Data Files         	        "
echo ============================================================================

#Read path of wave files and store it as a temporary file wavefilepaths.txt 
realpath ./raw/waves/train/*.wav > ./data/train/wavefilepaths.txt

echo "Creating the list of utterence IDs"

#Need to remove the hardcoding of 9 in next line.  The function is to extract the utterance id
cat ./data/train/wavefilepaths.txt | cut -d '/' -f 9 |cut -d '.' -f 1 > ./data/train/utt


echo "Creating the list of utterence IDs mapped to absolute file paths of wavefiles"


#Create wav.scp mapping from uttrence id to absolute wave file paths
paste ./data/train/utt ./data/train/wavefilepaths.txt > ./data/train/wav.scp


echo "Creating the list of Utterance IDs"

#Create speaker id list
cat ./data/train/utt | cut -d 'F' -f 1 > ./data/train/spk

echo "Creating the list of Utterance IDs mapped to corresponding speaker Ids"

#Create utt2spk
paste ./data/train/utt ./data/train/spk > ./data/train/utt2spk

echo "Creating the list of Speaker IDs mapped to corresponding list of utterance Ids"

#Create spk2utt
./utils/utt2spk_to_spk2utt.pl ./data/train/utt2spk > ./data/train/spk2utt

rm ./data/train/wavefilepaths.txt


echo ============================================================================
echo "                 MFCC Feature Extraction and Mean-Variance Tuning Files       	        "
echo ============================================================================

#Create feature vectors
./steps/make_mfcc.sh --nj 1 data/train exp/make_mfcc/train mfcc

#Copy the feature in text file formats for human reading
copy-feats ark:./mfcc/raw_mfcc_train.1.ark ark,t:./mfcc/raw_mfcc_train.1.txt


#Create Mean Variance Tuning
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/test mfcc

echo ============================================================================
echo "                  Preparing Language Model Files        	        "
echo ============================================================================
