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
mkdir -p data/local/dict

for folder in train test
do
mkdir data/$folder

echo ============================================================================
echo "                  Preparing Data Files for Featue extraction   	        "
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
echo "                 MFCC Feature Extraction and Mean-Variance Tuning Files       	        "
echo ============================================================================

#Create feature vectors
./steps/make_mfcc.sh --nj 1 data/$folder exp/make_mfcc/$folder mfcc

#Copy the feature in text file formats for human reading
copy-feats ark:./mfcc/raw_mfcc_$folder.1.ark ark,t:./mfcc/raw_mfcc_$folder.1.txt


#Create Mean Variance Tuning
steps/compute_cmvn_stats.sh data/$folder exp/make_mfcc/$folder mfcc



echo ============================================================================
echo "                  Preparing Data Files for Language Modeling  	        "
echo ============================================================================

#The function is to extract the utterance id
realpath ./raw/text/$folder/*.lab | xargs -l basename -s .lab > ./data/$folder/textutt

echo "Creating the list of transcripts"
paste -d '\n' ./raw/text/$folder/*.lab > ./data/$folder/trans

echo "Creating the text file of uttid mapped to transcript"
paste ./data/$folder/textutt ./data/$folder/trans > ./data/$folder/text


done

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

#kaldi_root_dir='../..'
kaldi_root_dir='/home/kavya/kavyadev/kaldi'
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



echo "===== MONO TRAINING ====="
echo

nj=1
steps/train_mono.sh --nj $nj --cmd "$train_cmd"  data/train data/$train_lang exp/mono  || exit 1


echo
echo "===== MONO DECODING ====="
echo
utils/mkgraph.sh --mono data/$train_lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode



echo
echo "===== MONO ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/$train_lang exp/mono exp/mono_ali || exit 1

echo
echo "===== TRI1 (first triphone pass) TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/$train_lang exp/mono_ali exp/tri1 || exit 1

echo "===== TRI1 (first triphone pass) DECODING ====="
echo
utils/mkgraph.sh data/$train_lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

# echo "===== TRI_LDA (second triphone pass) ALIGNMENT ====="
# echo
# steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri1 exp/tri1_ali

# echo "===== TRI_LDA (second triphone pass) LDA Training ====="
# echo

# steps/train_lda_mllt.sh --splice-opts "--left-context=2 --right-context=2" 2000 11000 data/train data/$train_lang exp/tri1_ali exp/tri_lda

# echo "===== TRI_LDA (second triphone pass) DECODING ====="
# echo
# utils/mkgraph.sh data/$train_lang exp/tri_lda exp/tri_lda/graph 
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_lda/graph data/test exp/tri_lda/decode


# echo "===== TRI_SAT (third triphone pass) ALIGNMENT ====="
# echo
# steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri_lda exp/tri_lda_ali

# echo "===== TRI_SAT (third triphone pass) SAT Training ====="
# echo


# steps/train_sat.sh  --cmd "$train_cmd" \
# 4200 40000 data/train data/$train_lang exp/tri_lda_ali exp/tri_sat || exit 1;


# echo "===== TRI_LDA (second triphone pass) DECODING ====="
# echo
# utils/mkgraph.sh data/$train_lang exp/tri_sat exp/tri_sat/graph 
# steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri_sat/graph data/test exp/tri_sat/decode


echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================