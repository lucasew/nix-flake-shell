#!/usr/bin/env -S nix run path:. --
// #!nix-flake-shell package nixpkgs.dotnetCorePackages.sdk_9_0
// #!nix-flake-shell prefix dotnet fsi
// #! vim:ft=fsharp

open System
open System.Net.Sockets
open System.Net
open System.Text

// Framework references are not supported: https://github.com/dotnet/fsharp/issues/9417

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
let host = "0.0.0.0"

let htmlData = "<img src=\"https://upload.wikimedia.org/wikipedia/pt/thumb/7/73/Trollface.png/220px-Trollface.png\" alt=\"trollface\"><h1>Problem?</h1>" 
let response = Encoding.ASCII.GetBytes($"HTTP/1.0 200 OK
Server: Baguncinha efesharpe
Content-Type: text-html; charset=utf-8

{htmlData}")


let server = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
server.Bind(IPEndPoint.Parse($"{host}:{port}"))
printfn "Listening on http://localhost:42069"
server.Listen(100)

let BUFFER_SIZE = 4096
let buffer = Array.zeroCreate BUFFER_SIZE

while true do
    let socket = server.Accept()
    printfn "Accept"
    let readSize = socket.Receive(buffer, 0, BUFFER_SIZE, SocketFlags.None) // read all the request discarding it
    printfn $"read {readSize} {Encoding.ASCII.GetString(buffer)}"
    socket.Send(response, response.Length, SocketFlags.None)
    socket.Close()

