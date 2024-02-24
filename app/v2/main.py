from bottle import route, run, response
from prometheus_client import start_http_server, Summary, generate_latest

REQUEST_TIME = Summary('request_processing_seconds', 'Time spent processing request')
count = 0


@route('/')
@REQUEST_TIME.time()
def index():
    global count
    count += 1
    print("Request: {}, version: 1.0.1".format(count))
    return "version: 1.0.1"


@route('/metrics')
def metrics():
    response.content_type = 'text/plain; version=0.0.4; charset=utf-8'
    return generate_latest()


if __name__ == '__main__':
    start_http_server(8000)
    run(host='0.0.0.0', port=8080)
