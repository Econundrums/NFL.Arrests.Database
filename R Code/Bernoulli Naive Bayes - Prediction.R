#General Notes
#You can run "tibble" dataframes through this function if you set the df
#parameter as NaiveBayes(as.data.frame(tibbleData), ...)


library(dplyr)
library(tm) #for functions VectorSource, VCorpus, and TermDocumentMatrix
library(tidyverse)
library(XLConnect)

NaiveBayes = function(trainData, testData, textColumn, outcomeColumn){

  train = trainData
  test = testData
  
  #Get a corpus of the training data and clean it by removing lower-case
  #letters, punctuation, English "stopwords", and whitespace.
  
  trainCorpus = VCorpus(VectorSource(train[, textColumn]))
  trainCorpus = trainCorpus %>% 
    tm_map(content_transformer(tolower)) %>%
    tm_map(removePunctuation) %>%
    tm_map(removeWords, stopwords(kind = "en")) %>%
    tm_map(stripWhitespace)
  
  #Gets a document term matrix to use for the actual algorithm and 
  #filters infrequent words
  
  dtmTrain = DocumentTermMatrix(trainCorpus)
  
  freqTerms = findFreqTerms(dtmTrain, 5)
  
  dtmTrain = DocumentTermMatrix(trainCorpus, control =
                                   list(dictionary = freqTerms))
  
  #Starts the Bernoulli Naive Bayes Algorithm
  
  #1. Extract vocabulary from training data
  vocab = Terms(dtmTrain)
  
  #2. Count the total number of documents N
  totDocs = nDocs(dtmTrain)
  
  #3. Get the prior probabilities for class 1 and class 0 -- i.e. N_c/N
  nClass0 = nrow(train[train[ ,outcomeColumn] == 0, ])
  nClass1 = nrow(train[train[ ,outcomeColumn] == 1, ])
  priorProb0 = nClass0 / totDocs
  priorProb1 = nClass1 / totDocs
  
  #4. Count the number of documents in each class 'c' containing term 't'
  trainTibble = as_tibble(as.matrix(dtmTrain))
  trainTibble$categ = train[,outcomeColumn]
  nDocsPerTerm0 = colSums(trainTibble[trainTibble$categ == 0, ])
  nDocsPerTerm1 = colSums(trainTibble[trainTibble$categ == 1, ])
  nDocsPerTerm0 = nDocsPerTerm0[-length(nDocsPerTerm0)]
  nDocsPerTerm1 = nDocsPerTerm1[-length(nDocsPerTerm1)]
  
  #5. Get the conditional probabilities for the data
  
  termCondProb0 = (nDocsPerTerm0 + 1)/(nClass0 + 2)
  termCondProb1 = (nDocsPerTerm1 + 1)/(nClass1 + 2)
  
  #6. Clean the test data
  
  testCorpus = VCorpus(VectorSource(test[,textColumn]))
  testCorpus = testCorpus %>% 
    tm_map(content_transformer(tolower)) %>%
    tm_map(removePunctuation) %>%
    tm_map(removeWords, stopwords(kind = "en")) %>%
    tm_map(stripWhitespace)
  
  dtmTest = DocumentTermMatrix(testCorpus)
  freqTermsTest = findFreqTerms(dtmTest, 5)
  dtmTest = DocumentTermMatrix(testCorpus, control =
                                   list(dictionary = freqTermsTest))
  
  #7. Extract vocab from test data
  vocabTest = Terms(dtmTest)
  
  #8. Classify the test data by computing the conditional probability that each document belongs to either
  # class1 or class 0, comparing said probabilities, and appending the results to an empty vector.
  
  classifiedRows = c()
  
  for (i in 1:nDocs(dtmTest)) {

    score0 = priorProb0
    score1 = priorProb1
  
     doc = colSums(as.matrix(dtmTest[i, ]))
     doc = doc[doc>0]
  
     for (j in 1:length(termCondProb0))
       if (names(termCondProb0)[j] %in% names(doc) == TRUE)
         score0 = score0 * unname(termCondProb0[j])
       else
         score0 = score0 *(1 - unname(termCondProb0[j]))
     
  
     for (k in 1:length(termCondProb1))
       if (names(termCondProb1)[k] %in% names(doc) == TRUE)
         score1 = score1 * unname(termCondProb1[k])
       else
         score1 = score1 * (1 - unname(termCondProb1[k]))
  
   if(score0 >= score1)
     classifiedRows = append(classifiedRows, 0)
   else
     classifiedRows = append(classifiedRows, 1)
  
     }
     
  return(classifiedRows)
  
}

path = "Data/NFL Player Arrests.xlsx"
train = as.data.frame(readWorksheetFromFile(path, sheet = "Training")) 
test = as.data.frame(readWorksheetFromFile(path, sheet = "Test")) 
predictions = NaiveBayes(train, test, "OUTCOME", "GUILTY")
test$GUILTY = predictions

wb = loadWorkbook(path)
createSheet(wb, "Results")
results = rbind(train, test)
writeWorksheet(wb, results, sheet = "Results")
saveWorkbook(wb, path)

