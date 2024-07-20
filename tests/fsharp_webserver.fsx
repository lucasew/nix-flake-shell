#!/usr/bin/env -S nix run path:. --
// #!nix-flake-shell package nixpkgs.dotnetCorePackages.sdk_9_0
// #!nix-flake-shell prefix dotnet fsi
// #! vim:ft=fsharp

open System

// Framework references are not supported: https://github.com/dotnet/fsharp/issues/9417

#r "nuget: Microsoft.AspNetCore.Http.Abstractions";;
#r "nuget: Microsoft.AspNetCore.Hosting.Abstractions";;
#r "nuget: Microsoft.AspNetCore.Hosting";;

#r "nuget: Saturn";;
open Saturn

#r "nuget: Giraffe";;
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

// let problemRoute (ctx) =
//     "<img src=\"https://upload.wikimedia.org/wikipedia/pt/thumb/7/73/Trollface.png/220px-Trollface.png\" alt=\"trollface\"><h1>Problem?</h1>"
//     |> htmlString
//     |> Response.ok ctx

// let app = application {
//     use_router problemRoute
// }

// run app

let app = application {
    use_router (text "Hello World from Saturn")
}

printfn "Listening on http://localhost:42069"
run app
