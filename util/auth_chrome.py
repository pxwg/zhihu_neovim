import argparse
import pychrome
import json
import time
import sys
import os
import contextlib
import threading
import logging
from websocket._exceptions import WebSocketConnectionClosedException
from pychrome.exceptions import RuntimeException

# Silence noisy loggers
logging.getLogger("websocket").setLevel(logging.CRITICAL)
logging.getLogger("pychrome").setLevel(logging.CRITICAL)

# Suppress uncaught thread exceptions from pychrome (_recv_loop) when Chrome closes
_original_threading_excepthook = threading.excepthook


def _silent_thread_excepthook(args):
    if isinstance(args.exc_value, WebSocketConnectionClosedException):
        return
    _original_threading_excepthook(args)


threading.excepthook = _silent_thread_excepthook  # type: ignore


@contextlib.contextmanager
def suppress_all_output():
    original_stdout = sys.stdout
    original_stderr = sys.stderr
    devnull_out = open(os.devnull, "w")
    devnull_err = open(os.devnull, "w")
    sys.stdout = devnull_out
    sys.stderr = devnull_err
    try:
        yield
    finally:
        sys.stdout = original_stdout
        sys.stderr = original_stderr
        devnull_out.close()
        devnull_err.close()


def connect_chrome(timeout=10, url="https://www.zhihu.com/", port=9222):
    start_time = time.time()
    while True:
        try:
            with suppress_all_output():
                browser = pychrome.Browser(url="http://localhost:" + str(port))
                _ = browser.list_tab()
                tabs = browser.list_tab()
                if not tabs:
                    tab = browser.new_tab(url)
                else:
                    tab = tabs[0]
                tab.start()
                tab.Page.navigate(url=url)
                tab.call_method("Network.enable")
            return browser, tab
        except Exception:
            if time.time() - start_time > timeout:
                raise TimeoutError(
                    f"Timeout waiting for Chrome after {timeout} seconds."
                )
            time.sleep(2)


def fetch_cookies(tab):
    try:
        with suppress_all_output():
            cookies = tab.call_method("Network.getAllCookies")
        return cookies.get("cookies", [])
    except Exception:
        return None


def cleanup_tab(tab):
    try:
        with suppress_all_output():
            tab.stop()
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--timeout",
        type=int,
        default=10,
        help="Timeout for waiting Chrome to open (seconds)",
    )
    parser.add_argument(
        "--url",
        type=str,
        default="https://www.zhihu.com/",
        help="URL to open in Chrome",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=9222,
        help="Port for Chrome remote debugging",
    )
    args = parser.parse_args()

    last_cookies = None
    try:
        browser, tab = connect_chrome(
            timeout=args.timeout, url=args.url, port=args.port
        )
    except TimeoutError as e:
        print(str(e))
        print("[]")
        return

    try:
        while True:
            with suppress_all_output():
                # Probe runtime
                tab.call_method("Runtime.evaluate", expression="1+1")
                cookies = fetch_cookies(tab)
            if cookies:
                last_cookies = cookies
            time.sleep(2)
    except (WebSocketConnectionClosedException, RuntimeException, Exception):
        # Silent exit on disconnect
        pass
    finally:
        if tab:
            cleanup_tab(tab)
        if last_cookies:
            cookie_dict = {c["name"]: c["value"] for c in last_cookies}
            print(json.dumps([cookie_dict], indent=2, ensure_ascii=False))
        else:
            print("[]")


if __name__ == "__main__":
    main()
