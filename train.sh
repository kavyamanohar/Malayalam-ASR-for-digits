#set-up for single machine or cluster based execution
. ./cmd.sh
#set the paths to binaries and other executables
[ -f path.sh ] && . ./path.sh


train_dict=dict
train_lang=lang_bigram
train_folder=train
nj=1


echo "===== MONO TRAINING ====="
echo

steps/train_mono.sh --nj $nj --cmd "$train_cmd"  data/train data/$train_lang exp/mono  || exit 1

echo
echo "===== MONO ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/$train_lang exp/mono exp/mono_ali || exit 1

echo
echo "===== TRI1 (first triphone pass) TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/$train_lang exp/mono_ali exp/tri1 || exit 1


echo "===== TRI_LDA (second triphone pass) ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri1 exp/tri1_ali

echo "===== TRI_LDA (second triphone pass) LDA Training ====="
echo

steps/train_lda_mllt.sh --splice-opts "--left-context=2 --right-context=2" 2000 11000 data/train data/$train_lang exp/tri1_ali exp/tri_lda


echo "===== TRI_SAT (third triphone pass) ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train/ data/$train_lang exp/tri_lda exp/tri_lda_ali

echo "===== TRI_SAT (third triphone pass) SAT Training ====="
echo


steps/train_sat.sh  --cmd "$train_cmd" \
4200 40000 data/train data/$train_lang exp/tri_lda_ali exp/tri_sat || exit 1;


echo ============================================================================
echo "                   End of Script             	        "
echo ============================================================================