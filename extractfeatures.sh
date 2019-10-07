#set-up for single machine or cluster based execution
. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


#Remove existing data
rm -rf data
rm -rf exp
rm -rf mfcc

#Create fresh data files
mkdir data

for folder in train test
do
mkdir data/$folder

echo ============================================================================
echo "                  Preparing Data Files for Featue extraction  for $folder	        "
echo ============================================================================



#Read path of wave files and store it as a temporary file wavefilepaths.txt 
realpath ./raw/waves/$folder/*.wav > ./data/$folder/wavefilepaths.txt

echo "Creating the list of utterence IDs"

#The function is to extract the utterance id
cat ./data/$folder/wavefilepaths.txt | xargs -l basename -s .wav > ./data/$folder/utt


echo "Creating the list of utterence IDs mapped to absolute file paths of wavefiles"


#Create wav.scp mapping from uttrence id to absolute wave file paths
paste ./data/$folder/utt ./data/$folder/wavefilepaths.txt > ./data/$folder/wav.scp


echo "Creating the list of speaker IDs"

#Create speaker id list
cat ./data/$folder/utt | cut -d '_' -f 1 > ./data/$folder/spk

echo "Creating the list of Utterance IDs mapped to corresponding speaker Ids"

#Create utt2spk
paste ./data/$folder/utt ./data/$folder/spk > ./data/$folder/utt2spk

echo "Creating the list of Speaker IDs mapped to corresponding list of utterance Ids"

#Create spk2utt
./utils/utt2spk_to_spk2utt.pl ./data/$folder/utt2spk > ./data/$folder/spk2utt

rm ./data/$folder/wavefilepaths.txt


echo ============================================================================
echo "     MFCC Feature Extraction and Mean-Variance Tuning Files for $folder    	        "
echo ============================================================================


#Create feature vectors
./steps/make_mfcc.sh --nj 1 data/$folder exp/make_mfcc/$folder mfcc

#Copy the feature in text file formats for human reading
copy-feats ark:./mfcc/raw_mfcc_$folder.1.ark ark,t:./mfcc/raw_mfcc_$folder.1.txt


#Create Mean Variance Tuning
steps/compute_cmvn_stats.sh data/$folder exp/make_mfcc/$folder mfcc


done


echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================