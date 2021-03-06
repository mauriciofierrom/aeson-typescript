{-# LANGUAGE QuasiQuotes, OverloadedStrings, TemplateHaskell, RecordWildCards, ScopedTypeVariables, NamedFieldPuns, KindSignatures #-}

module HigherKind (tests) where

import Data.Aeson as A
import Data.Aeson.TH as A
import Data.Aeson.TypeScript.TH
import Data.Aeson.TypeScript.Types
import Data.Monoid
import Data.Proxy
import Data.String.Interpolate.IsString
import Prelude hiding (Double)
import Test.Hspec
import Util


data HigherKind a = HigherKind { higherKindList :: [a] }
$(deriveTypeScript A.defaultOptions ''HigherKind)
$(deriveJSON A.defaultOptions ''HigherKind)

data Foo = Foo { fooString :: String
               , fooHigherKindReference :: HigherKind String }
$(deriveTypeScript A.defaultOptions ''Foo)

data DoubleHigherKind a b = DoubleHigherKind { someList :: [b]
                                             , higherKindThing :: HigherKind a }
$(deriveTypeScript A.defaultOptions ''DoubleHigherKind)
$(deriveJSON A.defaultOptions ''DoubleHigherKind)

data HigherKindWithUnary a = Unary Int
$(deriveTypeScript A.defaultOptions ''HigherKindWithUnary)
$(deriveJSON A.defaultOptions ''HigherKindWithUnary)


tests = describe "Higher kinds" $ do
  describe "Kind * -> *" $ do
    it [i|makes the declaration and types correctly|] $ do
      (getTypeScriptDeclarations (Proxy :: Proxy HigherKind)) `shouldBe` ([
        TSTypeAlternatives "HigherKind" ["T"] ["IHigherKind<T>"],
        TSInterfaceDeclaration "IHigherKind" ["T"] [TSField False "higherKindList" "T[]"]
        ])

      (getTypeScriptType (Proxy :: Proxy (HigherKind Int))) `shouldBe` "HigherKind<number>"
      (getTypeScriptType (Proxy :: Proxy (HigherKind String))) `shouldBe` "HigherKind<string>"

    it [i|works when referenced in another type|] $ do
      (getTypeScriptDeclarations (Proxy :: Proxy Foo)) `shouldBe` ([
        TSInterfaceDeclaration "Foo" [] [TSField False "fooString" "string"
                                        , TSField False "fooHigherKindReference" "HigherKind<string>"]
        ])

    it [i|works with an interface inside|] $ do
      (getTypeScriptDeclarations (Proxy :: Proxy HigherKindWithUnary)) `shouldBe` ([
        TSTypeAlternatives "HigherKindWithUnary" ["T"] ["IUnary<T>"],
        TSTypeAlternatives "IUnary" ["T"] ["number"]
        ])

  describe "Kind * -> * -> *" $ do
    it [i|makes the declaration and type correctly|] $ do
      (getTypeScriptDeclarations (Proxy :: Proxy DoubleHigherKind)) `shouldBe` ([
        TSTypeAlternatives "DoubleHigherKind" ["T1","T2"] ["IDoubleHigherKind<T1, T2>"],
        TSInterfaceDeclaration "IDoubleHigherKind" ["T1","T2"] [TSField False "someList" "T2[]"
                                                               , TSField False "higherKindThing" "HigherKind<T1>"]
        ])

      (getTypeScriptType (Proxy :: Proxy (DoubleHigherKind Int String))) `shouldBe` "DoubleHigherKind<number, string>"
      (getTypeScriptType (Proxy :: Proxy (DoubleHigherKind String Int))) `shouldBe` "DoubleHigherKind<string, number>"

  describe "TSC compiler checks" $ do
    it "type checks everything with tsc" $ do
      let declarations = ((getTypeScriptDeclarations (Proxy :: Proxy HigherKind)) <>
                          (getTypeScriptDeclarations (Proxy :: Proxy DoubleHigherKind)) <>
                          (getTypeScriptDeclarations (Proxy :: Proxy HigherKindWithUnary))
                         )

      let typesAndValues = [(getTypeScriptType (Proxy :: Proxy (HigherKind Int)) , A.encode (HigherKind [42 :: Int]))
                           , (getTypeScriptType (Proxy :: Proxy (HigherKind String)) , A.encode (HigherKind ["asdf" :: String]))

                           , (getTypeScriptType (Proxy :: Proxy (DoubleHigherKind String Int)) , A.encode (DoubleHigherKind [42 :: Int] (HigherKind ["asdf" :: String])))
                           , (getTypeScriptType (Proxy :: Proxy (DoubleHigherKind Int String)) , A.encode (DoubleHigherKind ["asdf" :: String] (HigherKind [42 :: Int])))

                           , (getTypeScriptType (Proxy :: Proxy (HigherKindWithUnary String)) , A.encode ((Unary 42) :: HigherKindWithUnary String))
                           ]

      testTypeCheckDeclarations declarations typesAndValues


main = hspec tests


main' = putStrLn $ formatTSDeclarations (
   (getTypeScriptDeclarations (Proxy :: Proxy HigherKind)) <>
   (getTypeScriptDeclarations (Proxy :: Proxy DoubleHigherKind)) <>
   (getTypeScriptDeclarations (Proxy :: Proxy HigherKindWithUnary))
  )
