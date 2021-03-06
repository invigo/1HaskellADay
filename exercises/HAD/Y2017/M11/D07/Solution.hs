{-# LANGUAGE OverloadedStrings, ViewPatterns #-}

module Y2017.M11.D07.Solution where

{--
Yesterday's exercise we read in a set of scored documents; the exercise before, 
we parsed a set of keywords associated with articles.

Today continues the parsing exercises. This time we're parsing JSON, so it 
'should' be easy. Right?

Given the structure at recommend.json parse in that structure
--}

import Control.Arrow ((&&&), (***))
import Data.Aeson hiding (Value)
import Data.Aeson.Encode.Pretty
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.List (isInfixOf)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromJust, mapMaybe)
import Data.Time

-- below import available via 1HaskellADay git repository

import Store.SQL.Util.Indexed

import Y2017.M11.D06.Solution hiding (title)
import Y2017.M11.D03.Solution

recommendFile :: FilePath
recommendFile = "Y2017/M11/D07/recommend.json"

data Recommend =
   Rec { recIdx, title :: String,
         text, author :: Maybe String,
         published :: Day,
         viewCnt :: Maybe Integer }
      deriving (Eq, Show)

instance FromJSON Recommend where
   parseJSON (Object o) =
      Rec <$> o .: "id" <*> o .: "title" <*> o .:? "full_text"
          <*> o .:? "author" <*> o .: "publish_dt" <*> o .: "view_count"

instance Indexed Recommend where
   idx (Rec i _ _ _ _ _) = read i

data RecommendSet = RS { unrecs :: [Recommend] }

instance FromJSON RecommendSet where
   parseJSON (Object o) = RS <$> o .: "recommend"

readRecs :: FilePath -> IO (Map Integer Recommend)
readRecs =
    fmap (Map.fromList . map (read . recIdx &&& id) . unrecs . fromJust . decode)
         . BL.readFile

-- How many recommendations are there? How many title have the word 'Trump' in 
-- them?

{--
>>> recs <- readRecs "Y2017/M11/D07/recommend.json"
>>> length recs
30
>>> length . filter (isInfixOf "Trump" . title) $ Map.elems recs
24
--}

{-- BONUS -----------------------------------------------------------------

From yesterday's exercise you loaded in a set of scores. Today you have a set of
recommendations ... without scores.

Marry the two. Now, output JSON in the following format:

article_id:  <<- make this an integer, not a string, smh
article_title:
article_body:
article_date:
article_keywords: <<- a list, leave empty for now
article_score:  <<- score goes here
article_author: <<- if present
--}

data Recommendation =
   Scored { scoreIdx :: Integer, 
            scoreTitle :: String,
            scoreText :: Maybe String, 
            scoreDate :: Day,
            scoreAuthor :: Maybe String,
            scoreKWs :: [Keyphrase],
            scoreViewCnt :: Maybe Integer,
            scoreScore :: Double }
      deriving (Eq, Show)

marry :: Map Integer Recommend -> Map Integer Score -> [Recommendation]
marry recs =
   mapMaybe (\(idx, val2float . score -> scr) ->
               Map.lookup idx recs >>= \rec ->
               return (Scored idx (title rec) (text rec) (published rec) 
                              (author rec) [] (viewCnt rec) scr))
       . Map.toList

-- how many recommendations did you get from that marriage?

{--
>>> scores <- readScoreFile scoreFile 
>>> length scores
30
>>> marriage = marry recs scores
>>> length marriage
30
--}

-- now, save out the recommendations as JSON:

instance ToJSON Recommendation where
   toJSON rec = object ["article_id" .= scoreIdx rec,
                        "article_title" .= scoreTitle rec,
                        "article_body" .= scoreText rec,
                        "article_date" .= scoreDate rec,
                        "article_keywords" .= scoreKWs rec,
                        "article_score" .= scoreScore rec,
                        "article_view_count" .= scoreViewCnt rec,
                        "article_author" .= scoreAuthor rec]

-- Of course, we need keyword JSON instance, but leave that undefined for now

instance ToJSON Keyphrase where
   toJSON (KW strength (SQS str)) =
         object ["strength" .= strength, "keyphrase" .= str]

writeRecs :: FilePath -> [Recommendation] -> IO ()
writeRecs outputFile = BL.writeFile outputFile . encodePretty

{--
>>> writeRecs "Y2017/M11/D07/recs_with_scores.json" marriage

... and you see the pprinted json of the recommendations with their scores.

Tomorrow, we will add the keywords for these specific articles and output this 
as JSON.
--}
