--
-- A automated solver for "scrambled equations" - a homework assignment for my 6th grade nephew.
--
-- For example, given the scrambed equation:
--   + 1 3 = 2
-- the possible unscrambled equations are:
--   1 + 2 = 3
--   3 = 1 + 2
--   3 = 2 + 1
--   2 + 1 = 3
--
-- The solver can be invoked to solve this problem using either:
--
--   ScrambedEquations> solve "+ 1 3 = 2"
--     => ["1 + 2 = 3","3 = 1 + 2","3 = 2 + 1","2 + 1 = 3"]
--
--   ScrambedEquations> solveTokens [Op Add, Num 1, Num 3, Equals, Num 2]
--     => ["1 + 2 = 3","3 = 1 + 2","3 = 2 + 1","2 + 1 = 3"]
--
module ScrambledEquations where

import Data.List (delete, nub, permutations)
import Control.Monad

data Op = Add | Sub | Div | Mul
  deriving (Eq, Show)

data Token
  = Num Integer
  | Op Op
  | Equals
  deriving (Eq, Show)

--type Parse s a = s -> Maybe (a, s)
newtype Parse s a = Parser {
  getParser :: s -> Maybe (a, s)
}

(==>) :: Parse s a -> (a -> Parse s b) -> Parse s b
p1 ==> aToP2 = 
  Parser $ \ts ->
    case (getParser p1) ts of
      Nothing -> Nothing
      Just (a, ts) -> (getParser (aToP2 a)) ts

(|||) :: Parse s a -> Parse s a -> Parse s a
p1 ||| p2 =
  Parser $ \ts ->
    case (getParser p1) ts of
      Nothing -> (getParser p2) ts
      x -> x

-- like {} in EBNF
-- e.g. num {mulOp num}
repeatParser :: a -> (a -> Parse s a) -> Parse s a
repeatParser left aToParser = (aToParser left) ||| (identity left)

identity :: a -> Parse s a
identity left = Parser $ \ts -> return (left, ts)

lexer :: Parse String [Token]
lexer = Parser $ \s -> case s of
  [] -> Just ([], [])
  s  -> (getParser (lexWhiteSpace ==> \_ -> 
          lexSingleToken ==> \a ->
            lexWhiteSpace ==> \_ ->
              lexer ==> \a2 -> identity (a:a2))) s

lexSingleToken :: Parse String Token
lexSingleToken = lexOp ||| lexNum

lexWhiteSpace :: Parse String ()
lexWhiteSpace = Parser $ \s -> Just ((), skipws s)

skipws :: String -> String
skipws = dropWhile (== ' ')

lexNum :: Parse String Token
lexNum = Parser $ \s ->
  case reads s of
    [(n, s)] -> Just (Num n, s)
    otherwise -> Nothing

lexOp :: Parse String Token
lexOp = Parser $ \s -> case s of
  (c:s) -> case c of
    '+' -> Just (Op Add, s)
    '-' -> Just (Op Sub, s)
    '*' -> Just (Op Mul, s)
    '/' -> Just (Op Div, s)
    '=' -> Just (Equals, s)
    otherwise -> Nothing
  _ -> Nothing

type Equation = [Token]

data Expr
  = ENum Integer
  | EEquals Expr Expr
  | EOp Op Expr Expr
  deriving (Eq, Show)

pprint :: Expr -> String
pprint (ENum n) = show n
pprint (EEquals e1 e2) = pprint e1 ++ " = " ++ pprint e2
pprint (EOp op e1 e2) = pprint e1 ++ " " ++ op2str op ++ " " ++ pprint e2

op2str Add = "+"
op2str Sub = "-"
op2str Div = "/"
op2str Mul = "*"

eval :: Expr -> (Integer, Integer, Bool)
eval (EEquals e1 e2) =
  let
    r1 = evalExpr e1
    r2 = evalExpr e2
  in (r1, r2, r1 == r2)

evalExpr (ENum n) = n
evalExpr (EOp Add e1 e2) = (evalExpr e1) + (evalExpr e2)
evalExpr (EOp Sub e1 e2) = (evalExpr e1) - (evalExpr e2)
evalExpr (EOp Mul e1 e2) = (evalExpr e1) * (evalExpr e2)
evalExpr (EOp Div e1 e2) = (evalExpr e1) `div` (evalExpr e2)

type ParseExpr a = Parse [Token] a

-- expr1 = expr2
parse :: ParseExpr Expr
parse =
  parseExpr ==> \e1 ->
    parseEquals ==> \_ ->
      parseExpr ==> \e2 ->
        identity (EEquals e1 e2)

parseExpr :: ParseExpr Expr
parseExpr = parseExprL1

parseExprL1 :: ParseExpr Expr
parseExprL1 =
  parseExprL2 ==> \e1 ->
    parseExprL1Tail e1

parseExprL1Tail :: Expr -> ParseExpr Expr
parseExprL1Tail left = repeatParser left l1Tail

l1Tail :: Expr -> ParseExpr Expr
l1Tail left =
  parseOp1 ==> \op1 ->
    parseExprL2 ==> \e2 ->
      parseExprL1Tail (EOp op1 left e2)

parseExprL2 :: ParseExpr Expr
parseExprL2 =
  parseExprL3 ==> \e1 ->
    parseExprL2Tail e1

-- 2 * 3 * 4 => (2 * 3) * 4
parseExprL2Tail :: Expr -> ParseExpr Expr
parseExprL2Tail left = repeatParser left l2Tail

l2Tail :: Expr -> ParseExpr Expr
l2Tail left =
  parseOp2 ==> \op2 ->
    parseExprL3 ==> \e2 ->
      parseExprL2Tail (EOp op2 left e2)

parseExprL3 = parseNum

parseEquals :: ParseExpr Token
parseEquals = Parser $ \ts -> case ts of
  (Equals:ts) -> Just (Equals, ts)
  otherwise   -> Nothing

-- Operators with precedence 1
parseOp1 :: ParseExpr Op
parseOp1 = Parser $ \ts -> case ts of
  (Op Add:ts) -> Just (Add, ts)
  (Op Sub:ts) -> Just (Sub, ts)
  otherwise   -> Nothing

-- Operators with precedence 2
parseOp2 :: ParseExpr Op
parseOp2 = Parser $ \ts -> case ts of
  (Op Mul:ts) -> Just (Mul, ts)
  (Op Div:ts) -> Just (Div, ts)
  otherwise   -> Nothing

parseNum :: ParseExpr Expr
parseNum = Parser $ \ts -> case ts of
  (Num n:ts) -> Just (ENum n, ts)
  otherwise   -> Nothing

equationToExpr :: [Token] -> Maybe Expr
equationToExpr ts = (getParser parse) ts >>= \r ->
  case r of
    (e, [])   -> Just e
    otherwise -> Nothing

uniquePermutations :: Eq a => [a] -> [[a]]
uniquePermutations = nub . permutations

-- TODO: Avoid brute force.
goodPermutations :: Equation -> [Equation]
goodPermutations equation = uniquePermutations equation

goodExprs :: Equation -> [Expr]
goodExprs equation = map grabExpr $ filter (not . (== Nothing)) (map equationToExpr (goodPermutations equation))
  where
    grabExpr (Just e) = e

solveTokens :: Equation -> [String]
solveTokens ts = map (\(e, (a,_,_)) -> pprint e) good
  where
    exprs = goodExprs ts
    results = map eval exprs
    good = filter (\(e, (_,_,b)) -> b) (zip exprs results)

solve s = grabMaybe ((getParser lexer) s >>= \(tokens, "") -> Just $ solveTokens tokens)
  where
    grabMaybe (Just a) = a
    grabMaybe Nothing = []

equation1 = [Num 3, Num 27, Equals, Num 24, Op Add]
equationString1 = "3 27 = 24 +"
prob1a = solveTokens equation1
prob1b = solve equationString1
-- 24 + 3 = 27, 3 + 24 = 27, 27 = 3 + 24, 27 = 24 + 3

equation2 = [Num 13, Op Sub, Num 15, Num 28, Equals]
equationString2 = "13 - 15 28 ="
prob2a = solveTokens equation2
prob2b = solve equationString2
-- 28 - 15 = 13, 28 - 13 = 15, 13 = 28 - 15, ...

equation3 = [Num 3, Op Sub, Num 7, Equals, Op Mul, Num 5, Num 4]
equationString3 = "3 - 7 = * 5 4"
prob3a = solveTokens equation3
prob3b = solve equationString3
-- 3 x 4 - 7 = 5, 4 x 3 - 7 = 5, 4 x 3 - 5 = 7, 3 x 4 - 5 = 7

equation4 = [Equals, Num 5, Op Sub, Num 9, Num 31, Op Mul, Num 4]
equationString4 = "= 5 - 9 31 * 4"
prob4a = solveTokens equation4
prob4b = solve equationString4
-- 4 x 9 - 5 = 31, 4 x 9 - 31 = 5, 9 x 4 - 5 = 31, 9 x 4 - 31 = 5

equation5 = [Op Mul, Op Add, Equals, Num 25, Num 11, Num 3, Num 2]
equationString5 = "* + = 25 11 3 2"
prob5a = solveTokens equation5
prob5b = solve equationString5
-- 11 x 2 + 3 = 25, 11 x 3 + 2 = 25, 2 x 11 + 3 = 25, 25 = ..., ...

probs = [(prob1a, prob1b), (prob2a, prob2b), (prob3a, prob3b), (prob4a, prob4b), (prob5a, prob5b)]

printProbs = mapM_ (\(a,b) -> do putStrLn $ show a; putStrLn $ show b; putStrLn "") $ probs

-- Expression evaluation tests.

test actual expect =
  if expect /= actual
  then Left $ "FAIL:- expect: " ++ show expect ++ " actual: " ++ show actual
  else Right True

grab (Just a) = a

stringToExpr s = grab $ (getParser lexer) s >>= \(ts, "") -> Just ts

evalString s = (getParser lexer) s >>= \(a, _) -> (getParser parseExpr) a >>= \(a, _) -> Just . evalExpr $ a

grabEvalString s = grab $ evalString s

stringEvalEq s eq = stringToExpr s == eq

testProbs = map (\(actual, expect) -> test actual expect) probs

tests =
  [test (stringEvalEq equationString1 equation1) True
  ,test (stringEvalEq equationString2 equation2) True
  ,test (stringEvalEq equationString3 equation3) True
  ,test (stringEvalEq equationString4 equation4) True
  ,test (stringEvalEq equationString5 equation5) True
  ,test (evalString "1") (Just 1)
  ,test (evalString "") Nothing
  ,test (evalString "+") Nothing
  ,test (evalString "=") Nothing
  ,test (evalString "1+1") (Just 2)
  ,test (evalString "1 + 1 ") (Just 2)
  ,test (evalString "1 + 2") (Just 3)
  ,test (evalString "2 + 2 / 2") (Just 3)
  ,test (evalString "2 / 2 + 2") (Just 3)
  ,test (grabEvalString "1-2-3") (-4)
  ,test (grabEvalString "6/3/2") 1
  ,test (length (solve "1=1+2")) 2
  ,test (length (solve "1 1 1 = *")) 2
  ] ++ testProbs

executeTests = mapM_ (putStrLn . show) $ filter failed tests
  where
    failed (Left _) = True
    failed (Right _) = False
