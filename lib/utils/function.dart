getIp() {
  // return "http://64.227.151.183:4051/api";
  return _ip;
  // return "http://10.150.50.23:4050/api";
}

String _ip = "";

void saveIp(String ip) {
  _ip = ip;
}
