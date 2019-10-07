This is a [kaldi](https://kaldi-asr.org/) based recipie for Malayalam digit recognition. You need a working Kaldi directory to run this script.

Details on how to run this script and the working is described here.



# RAW DATA 


`/raw` has all the data available at the beginning of the project

- `/wav` (wave files. File names are of the form `utteranceID.wav`)
    - `/train`
    - `/test`
- `/text`(transcript of wave files by the name `utteranceID.lab`)
    - `/train`
    - `/test`
- `/language`
    - `/lexicon` (the phonetic transcript of words in the language vocabulary)

# SPEECH FEATURE EXTRACTION

To extract the features from audio clips, run the following script. 
```
$./extractfeatures.sh
```
It prepares the data and extract features as described below.

## DATA PREPARATION

From the `/raw` directory a `/data` directory is created with the following contents. This representation is important for further processing with kaldi tools.

- `/data`
    - `/train`
        - `utt` (List of utterance IDs)
        - `wav.scp` (Utterance IDs mapped to absolute wavefile paths)
        - `spk` (List of speaker IDs)
        - `utt2spk` (List of utterences corresponding to a speaker)
        - `spk2utt` (Speaker mapped to every utterance ID)

    - `/test`
        - `utt` (List of utterance IDs)
        - `wav.scp` (Utterance IDs mapped to absolute wavefile paths)
        - `spk` (List of speaker IDs)
        - `utt2spk` (List of utterences corresponding to a speaker)
        - `spk2utt` (Speaker mapped to every utterance ID)


## MFCC and CMVN

MFCC features are extracted and stored in `.ark` format in `/mfcc` directory. CMVN tuned features are also in the same directory in `.ark` format. The absolute filepaths of these ark files corresponding to each speaker (for cmvn) and for each utterance (for raw mfcc) are stored in corresponding `.scp` files. This needs the data prepared in the previous step.

- `/mfcc`
    - `raw_mfcc_train.ark`
    - `raw_mfcc_test.ark`
    - `cmvn_train.ark`
    - `cmvn_test.ark`
    - `raw_mfcc_test.scp`
    - `raw_mfcc_train.scp`
    - `cmvn_train.scp`
    - `cmvn_test.scp`

In parallel `/data/train` and `/data/test` are also populated with `cmvn.scp` and  `feats.scp`

 The log files for these feature extraction process are stored in `/exp/make_mfcc` in separate sub directories

 - `/exp/make_mfcc`
    - `/test`
        - log files
    - `/train`
        - log files


# LANGUAGE MODEL CREATION

To create the n-gram  language model, run the following script. Note that it uses the data folders previously prepared by the `$./extractfeatures` script. So make sure you run that script prior to `$./createLM.sh`
```
$./createLM.sh
```

It prepares the data and n-gram language model as described below.

## DATA PREPARATION

It runs on the training data directory. From the `/raw` data directory of transcrips create files of utterenceID, speech trascript, and their mapping files.

- `/data`
    - `/train`
        - `textutt` (List of utteranceIDs. It is currenty same as utt)
        - `trans` (List of all transcripts)
        - `text` (UtteranceID to transcript mapping)
        - `lm_train.txt` (Lit of utterances with sentance begin and end markers. This the file used for n-gram LM creation)

From the `/raw` data directory of language vocabulary lexicon, a list of phones in `/data/local/dict`

- `/data`
    - `/local`
        - `/dict`
            - extra_phones.txt
            - extra_questions.txt
            - lexiconp.txt  
            - lexicon.txt
            - nonsilence_phones.txt
            - optional_silence.txt
            - phones.txt
            - silence_phones.txt

## N-gram language model creation

Once the data is ready n-gram language model can be created. Here it is done using IRSTLM toolkit.It prodices language model in ARPA format. Final language model in FST format, `G.fst` is available in `/data/lang_ngram/G.fst`.

# TRAINING GMM-HMM

To run the script for training and decoding,

```
$train_decode.sh
```

There are different options for training and Decoding. 

- monophone 
- triphone 
- triphone LDA
- triphone SAT

Once training is done, there will be decoding graphs available in `/exp` directory.

Decoding will display corresponding word error rate (WER) and Sentance error rates (SER) in percentage


# DO FEATURE EXTRACTION, LM CREATION, TRAINING and DECODING all at once

```
$run.sh
```


# TRANSCRIBE your Speech

If you have an audio clip of Malayalam digit utterance, you can transcribe it using the trained model in `/exp`. Keep your audio file in wave format in `/inputaudio` directory and run,

```
$/transcribe.sh
```

The result will in `/inputaudio/transcriptions/one-best-hypothesis.txt`


