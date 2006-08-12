


module Score.Main where


import Hoogle.Database
import Hoogle.MatchType
import Hoogle.Parser
import Hoogle.MatchClass
import Hoogle.Result
import Hoogle.TypeSig
import Hoogle.General

import System.Environment
import Data.Maybe
import Data.List
import Data.Char


type Phrase = [[Char]]

type Tag = (Int, Int)

type Knowledge = [(Phrase, Phrase, Tag)]
type Know = [(String, String, Tag)]


reasons :: [MatchAmount]
reasons = [minBound..maxBound]

codes = length reasons * 2

reasonToCode :: Reason -> Char
reasonToCode (ReasonLeft x) = fromJust $ lookup x $ zip reasons ['a'..]
reasonToCode (ReasonRight x) = chr $ length reasons + ord (reasonToCode (ReasonLeft x))


codeToReason :: Char -> Reason
codeToReason x = fromJust $ lookup x $ zip ['a'..] $ map ReasonLeft reasons ++ map ReasonRight reasons


main = do x <- return ["examples.txt"] -- getArgs
          db <- loadDatabase "classes.txt"
          y <- mapM (loadExample (classes db)) x
          let knowledge = simpAll $ concatMap simpKnow $ concat y
              res = "test"
          writeFile "score.ecl" (eclipse knowledge)
          putStr $ showKnowledge knowledge


simpAll xs = map fst $ filter f $ pickOne $ nub xs
    where
        f (x, xs) = not $ any (less x) xs
        
        -- is the first one completely subsumed by the second
        -- i.e. the first can be deleted
        -- only if there is more on the lefts, and less on the right
        less (a1,a2,a3) (b1,b2,b3) = null (a1 \\ b1) && null (b2 \\ a2)



simpKnow (a,b,c) = if null aa then [] else [(aa,bb,c)]
    where
        (aa, bb) = simpPair (sa, sb)
        ([sa], [sb]) = (simp a, simp b)



pickOne :: [a] -> [(a, [a])]
pickOne xs = init $ zipWith f (inits xs) (tails xs)
    where f a (b:bs) = (b, a ++ bs)
    

simp x = map fst $ filter f $ pickOne $ nub $ map sort x
    where
        f (x, xs) = not $ any (less x) xs
        less a b = let (_, res) = simpPair (a,b) in null res



simpPair :: (String, String) -> (String, String)
simpPair (a,b) = f (sort a) (sort b)
    where
        f (x:xs) (y:ys) | x == y = f xs ys
                        | x <  y = let (a,b) = f xs (y:ys) in (x:a,b)
                        | x >  y = let (a,b) = f (x:xs) ys in (a,y:b)
        f xs ys = (xs, ys)


showKnowledge :: Know -> String
showKnowledge xs = unlines $ map f xs
    where
        f (a,b,(a1,b1)) = g a ++ " < " ++ g b ++ " [" ++ show a1 ++ "<" ++ show b1 ++ "]"
        g xs = xs -- show $ map codeToReason xs


loadExample :: ClassTable -> String -> IO Knowledge
loadExample ct file = do x <- readFile file
                         return $ concatMap (trans . order) $ bundle
                                $ filter (validLine . snd) $ zip [1..] $ lines x
    where
        bundle []     = []
        bundle (x:xs) = ((fst x, tail (snd x)):a) : bundle b
            where (a, b) = break (\x -> head (snd x) == '@') xs

        order ((n,x):xs) = map (\(a,b) -> (,) a $ map (map reasonToCode) $ compareTypes ct (f b) (f x)) xs
                    
        f = fromLeft . parseConType
        
        trans [] = []
        trans ((n,x):xs) = map (\(a,b) -> (x,b,(n,a))) xs ++ trans xs



-- Make Alan Frish happy
eclipse :: Know -> String
eclipse xs = unlines $ header ++ map f xs ++ footer
    where
        f (a,b,(a1,b1)) = "    " ++ g a ++ " #< " ++ g b ++ ","
        g xs = intersperse '+' (map toUpper xs)

        header = [
            "% Generated by Hoogle Score",
            ":- lib(fd).",
            "same(X,X).",
            "range([]).",
            "range([X|Xs]) :-",
            "    X :: [1..100],",
            "    range(Xs).",
            "solver(Xs) :-",
            "    same(Xs, [" ++ intersperse ',' (take codes ['A'..'Z']) ++ "]),",
            "    range(Xs),"]
            
        footer = [
            "    labeling(Xs)."]
            


