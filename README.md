# KissPanel

KissPanel is a lightweight, modern web hosting control panel designed to be simple, secure, and efficient.

## Quick Install

```bash
wget https://raw.githubusercontent.com/kisspanel/kisspanel/main/kisspanel-install.sh
chmod +x kisspanel-install.sh
./kisspanel-install.sh
```

## Installation Builder

Use our interactive installation builder to create your custom installation command:
[KissPanel Installation Builder](https://kisspanel.github.io/kisspanel/)

This tool helps you:
- Select desired components
- Configure installation options
- Generate the complete installation command

## System Requirements

- **Operating Systems:**
  - AlmaLinux 8.x, 9.x
  - Ubuntu 22.04 LTS
- **Minimum Hardware:**
  - 1GB RAM (2GB+ recommended)
  - 10GB free disk space
  - 1 CPU core (2+ recommended)
- **Network:**
  - Static IP address
  - Full internet access for installation

## Features

- **Web Server Management**
  - Nginx web server
  - PHP-FPM support
  - SSL certificate management

- **Database Management**
  - SQLite (core)
  - MariaDB support
  - PostgreSQL support

- **Mail Services**
  - Exim mail server
  - Dovecot IMAP/POP3
  - Webmail interface

- **DNS Management**
  - BIND DNS server
  - Zone management
  - DNS clustering support

- **Security Features**
  - Firewall management
  - SSL/TLS support
  - Fail2ban integration
  - Regular security updates

## Installation Options

```bash
# Basic installation with default settings
./kisspanel-install.sh

# Custom installation with specific options
./kisspanel-install.sh --port 2083 --hostname panel.yourdomain.com
```

For all available options, run:
```bash
./kisspanel-install.sh --help
```

## Testing

We provide both manual and automated testing procedures:

- **Manual Testing:** See [TESTING.md](TESTING.md) for step-by-step testing instructions
- **Automated Testing:** Run our test suite after installation:
  ```bash
  wget https://raw.githubusercontent.com/kisspanel/kisspanel/main/tools/test-install.sh
  chmod +x test-install.sh
  ./test-install.sh
  ```

## Documentation

- [Installation Guide](docs/installation.md)
- [User Guide](docs/user-guide.md)
- [API Documentation](docs/api.md)
- [FAQ](docs/faq.md)

## Support

- [GitHub Issues](https://github.com/kisspanel/kisspanel/issues)
- [Documentation](https://docs.kisspanel.org)
- [Community Forum](https://forum.kisspanel.org)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

KissPanel is open-source software licensed under the [MIT license](LICENSE).

## Security

Found a security issue? Please email security@kisspanel.org or see our [Security Policy](SECURITY.md).

## Roadmap

See our [project roadmap](ROADMAP.md) for planned features and improvements.

## Acknowledgments

KissPanel builds upon the work of many open source projects and is inspired by other control panels in the hosting industry.