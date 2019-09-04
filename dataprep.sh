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
mkdir -p data/local/dict
echo ============================================================================
echo "                  Preparing Data Files for Featue extraction   	        "
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
echo "                  Preparing Language Model Data Files        	        "
echo ============================================================================

#Need to remove the hardcoding of 9 in next line.  The function is to extract the utterance id
realpath ./raw/text/train/*.lab | cut -d '/' -f 9 | cut -d '.' -f 1 > ./data/train/textutt

echo "Creating the list of trascripts"
paste -d '\n' ./raw/text/train/*.lab > ./data/train/trans

echo "Creating the text file of uttid mapped to transcript"
paste ./data/train/textutt ./data/train/trans > ./data/train/text


echo "Creating LM model creation input file"
while read line
do
echo "<s> $line </s>" >> ./data/train/lm_train.txt
done <./data/train/trans


echo ============================================================================
echo "                  Preparing the Language Dictionary       	        "
echo ============================================================================
echo "Creating the sorted lexicon file"
sort ./raw/language/lexicon.txt | paste > ./data/local/dict/lexicon.txt 


echo "Creating the list of Phones"
cat ./data/local/dict/lexicon.txt | cut -d '	' -f 2  - | tr ' ' '\n' | sort | uniq > ./data/local/dict/phones.txt 

cat ./data/local/dict/phones.txt | sed /sil/d > ./data/local/dict/nonsilence_phones.txt 

echo "sil" > ./data/local/dict/silence_phones.txt 
echo "sil" > ./data/local/dict/optional_silence.txt 


touch ./data/local/dict/extra_phones.txt ./data/local/dict/extra_questions.txt



echo ============================================================================
echo "                  Preparing the Language Model Files    	        "
echo ============================================================================

kaldi_root_dir='/home/kavya/kavyadev/kaldi/'
basepath='.'


lm_arpa_path=$basepath/data/local/lm

train_dict=dict
train_lang=lang_bigram
train_folder=train

n_gram=2 # This specifies bigram or trigram. for bigram set n_gram=2 for tri_gram set n_gram=3

echo ============================================================================
echo "                   Creating  n-gram LM               	        "
echo ============================================================================

rm -rf $basepath/data/local/$train_dict/lexiconp.txt $basepath/data/local/$train_lang $basepath/data/local/tmp_$train_lang $basepath/data/$train_lang
mkdir $basepath/data/local/tmp_$train_lang

utils/prepare_lang.sh --num-sil-states 3 data/local/$train_dict '!sil' data/local/$train_lang data/$train_lang

$kaldi_root_dir/tools/irstlm/bin/build-lm.sh -i $basepath/data/$train_folder/lm_train.txt -n $n_gram -o $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | utils/find_arpa_oovs.pl data/$train_lang/words.txt  > data/local/tmp_$train_lang/oov.txt

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | grep -v '<s> <s>' | grep -v '<s> </s>' | grep -v '</s> </s>' | grep -v 'SIL' | $kaldi_root_dir/src/lmbin/arpa2fst - | fstprint | utils/remove_oovs.pl data/local/tmp_$train_lang/oov.txt | utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/$train_lang/words.txt --osymbols=data/$train_lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > data/$train_lang/G.fst 
$kaldi_root_dir/src/fstbin/fstisstochastic data/$train_lang/G.fst 

echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================

