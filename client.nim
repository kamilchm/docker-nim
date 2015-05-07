import posix

const UnixPathMax = 108

type
  Docker = object
    socketPath*: string
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
  return Docker(socketPath: socketPath)

proc connect(client: var Docker) : void {.raises: [IOError].} =
  var sockAddr: SockAddrUn
  sockAddr = unixSocket(client.socketPath)
  const SockAddrHeadLen = 2
  var sockLen = Socklen(client.socketPath.len + SockAddrHeadLen)

  let sock = socket(AF_UNIX, SOCK_STREAM, 0)
  let r = sock.connect(cast[ptr SockAddr](addr sockAddr), sockLen)
  if r != 0:
    raise newException(IOError, "Unable to connect to docker unix socket " & client.socketPath)

  client.socket = sock

proc call(client: var Docker, reqBody: string) : string =
  client.connect()
  discard write(cint(client.socket), cstring(reqBody), cint(reqBody.len))

  result = ""
  var buff: array[4096, char]
  while read(cint(client.socket), addr buff, 4095) > 0:
    result.add(buff)

proc version*(client: var Docker) =
  echo(client.call("GET /version HTTP/1.0\r\n\r\n"))

proc info*(client: var Docker) =
  echo(client.call("GET /info HTTP/1.0\r\n\r\n"))

var client = newClient()
client.version()
client.info()
