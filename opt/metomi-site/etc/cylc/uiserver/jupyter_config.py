# Insecure workaround for browser permissions error
# See https://stackoverflow.com/questions/70753768/jupyter-notebook-access-to-the-file-was-denied
c.ServerApp.use_redirect_file = False

if 'path' in locals():
    # Cylc Hub ONLY

    from pathlib import Path
    import re
    import sys

    c.JupyterHub.bind_url = 'http://:80'

    from cylc.review.ws import get_review_service_config
    c.JupyterHub.services = [get_review_service_config()]
    c.JupyterHub.load_roles = [
        {
            "name": "user",
            "scopes": ["self", "access:services!service=cylc-review"],
        },
    ]

    # Specify the location of the JupyterHub runtime files
    RUNTIME_PATH = Path('~/.cylc/uiserver').expanduser()
    c.JupyterHub.cookie_secret_file = f'{RUNTIME_PATH / "cookie_secret"}'
    c.JupyterHub.db_url = f'{RUNTIME_PATH / "jupyterhub.sqlite"}'
    c.ConfigurableHTTPProxy.pid_file = f'{RUNTIME_PATH / "jupyterhub-proxy.pid"}'

    # Create a self signed certificate if certificate directory not found
    CERT_PATH = Path(RUNTIME_PATH, "cert")
    if not CERT_PATH.exists():
        CERT_PATH.mkdir(parents=True)
        from subprocess import Popen
        proc = Popen([
            # path to the openssl executable in this environment
            re.sub(r'python(\d[\.\d]*)?$', 'openssl', sys.executable),
            'req',
            '--x509',
            '--nodes',
            '--days=3650',
            '--newkey=rsa:2048',
            '--subj=/O=Cylc',
            f'--keyout={CERT_PATH / "self_signed.key"}',
            f'--out={CERT_PATH / "self_signed.crt"}'
        ])
        if proc.wait():
            raise Exception('Could not create certificate')
    #c.JupyterHub.ssl_cert = f'{CERT_PATH / "self_signed.crt"}'
    #c.JupyterHub.ssl_key = f'{CERT_PATH / "self_signed.key"}'
