import posix

const UnixPathMax = 108

type
  Docker = object
    socket: SocketHandle

  SockAddrUn = object ## struct sockaddr_un
    family*: TSa_Family         ## Address family.
    path*: array [0..UnixPathMax, char] ## Socket address (variable-length data).

proc unixSocket(sockPath: string): SockAddrUn =
  result = SockAddrUn(family: AF_UNIX)
  var cnt = 0

  for c in sockPath:
    result.path[cnt] = c
    cnt.inc()

proc newClient*(socketPath: string = "/var/run/docker.sock") : Docker =
  var sockAddr: SockAddrUn
  sockAddr = unixSocket(socketPath)
  echo(sockAddr)

  let sock = socket(AF_UNIX, SOCK_STREAM, 0)
  let r = sock.connect(cast[ptr SockAddr](addr sockAddr), 23)
  if r != 0:
    try:
      writeln(stderr, "Unable to connect to docker unix socket " & socketPath)
      return
    except IOError:
      return

  return Docker(socket: sock)

proc call(client: Docker, reqBody: string) : string =
  discard write(cint(client.socket), cstring(reqBody), cint(reqBody.len))

  var response: array[4096, char]
  discard read(cint(client.socket), addr response, 4095)

  return $response

proc version*(client: Docker) =
  echo(client.call("GET /version HTTP/1.0\r\n\r\n"))

proc info*(client: Docker) =
  echo(client.call("GET /info HTTP/1.0\r\n\r\n"))

let client = newClient()
client.version()
client.info()
