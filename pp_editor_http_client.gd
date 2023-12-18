@tool

const ERROR = 1
const OK = 0

var _host = "https://golang.planetaryprocessing.io"
var _port = 443
var _error = ""
var _response = ""

var client = HTTPClient.new()

func get(url):
	return _request( HTTPClient.METHOD_GET, url, "" )

func post(url, body):
	return _request( HTTPClient.METHOD_POST, _host + url, JSON.stringify(body))

func _request(method, url, body):
	_response = ""
	var res = _connect()
	assert(res == OK, _error)
	client.request( method, url, [], body)
	
	res = _poll()
	assert(res == OK, _error)
	
	var responseByteArray = _parseBody()
	print(responseByteArray.get_string_from_ascii())
	
	client.close()
	return _response

func _connect():
	client.connect_to_host(_host, _port)
	var res = _poll()
	if( res != OK ):
		return ERROR
	return OK
	
func _setError(msg):
	_error = str(msg)
	return ERROR

func _poll():
	var status = -1
	var current_status
	while(true):
		client.poll()
		current_status = client.get_status()
		if( status != current_status ):
			status = current_status
			print("HTTPClient entered status ", status)
			if( status == HTTPClient.STATUS_RESOLVING ):
				continue
			if( status == HTTPClient.STATUS_REQUESTING ):
				continue
			if( status == HTTPClient.STATUS_CONNECTING ):
				continue
			if( status == HTTPClient.STATUS_CONNECTED ):
				return OK
			if( status == HTTPClient.STATUS_DISCONNECTED ):
				return _setError("Disconnected from Host")
			if( status == HTTPClient.STATUS_CANT_RESOLVE ):
				return _setError("Can't Resolve Host")
			if( status == HTTPClient.STATUS_CANT_CONNECT ):
				return _setError("Can't Connect to Host")
			if( status == HTTPClient.STATUS_CONNECTION_ERROR ):
				return _setError("Connection Error")
			if( status == HTTPClient.STATUS_BODY ):
				return OK

func _parseBody():
	var responseByteArray = PackedByteArray()

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			if not OS.has_feature("web"):
				OS.delay_usec(1000)
		else:
			responseByteArray = responseByteArray + chunk

	var response_code = client.get_response_code()
	assert(response_code >= 200 && response_code < 300, "HTTP Error status code:" + str(response_code) )
	return responseByteArray
