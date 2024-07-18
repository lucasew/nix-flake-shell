#!/usr/bin/env -S nix run path:. --
// #!nix-flake-shell package nixpkgs.fsharp
// #!nix-flake-shell prefix fsharpi 
// #! vim:ft=fsharp

open System

// Introduced in F# 5 -- https://stackoverflow.com/questions/66415290/where-to-keep-nuget-packages-for-fsi-scripts-f
// Blocker because nixpkgs right now has only F# 4 available
// Local works tho
// TODO: test properly after bump
#r "nuget: Saturn"
open Saturn

open Giraffe

let optionalize x =
    if (isNull x) then
        None
    else
        Some(x)

let getEnv key =
    optionalize (Environment.GetEnvironmentVariable key)

let getEnvOr key fallback =
    match getEnv key with
    | Some x -> x
    | None -> fallback

let port = getEnvOr "PORT" "42069"

let host = sprintf "http://0.0.0.0:%s/" port

let problemRoute ctx =
    "<img src=\"https://upload.wikimedia.org/wikipedia/pt/thumb/7/73/Trollface.png/220px-Trollface.png\" alt=\"trollface\"><h1>Problem?</h1>"
    |> htmlString
    |> Response.ok ctx

let rootRouter = router {
    getf "/" problemRoute
}

let app = application {
    use_router rootRouter
    url host
}

printfn "Listening on http://localhost:42069"
run app
