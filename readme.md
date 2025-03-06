# Education Platform Docker Setup

A comprehensive Docker-based deployment solution for educational institutions, featuring Moodle LMS and openSIS (Student Information System) with automated SSL certificate management through Traefik.

## Features

- **Moodle LMS**: A robust learning management system
- **openSIS**: Complete student information management system
- **Traefik**: Automatic SSL certificate management and reverse proxy
- **Docker-based**: Easy deployment and scaling
- **Secure by Default**: HTTPS enforced with automatic certificate management
- **Multi-Database Support**: PostgreSQL for Moodle and MariaDB for openSIS

## Prerequisites

- Docker Engine
- Docker Compose
- Git
- Domain names pointed to your server for:
  - Traefik dashboard
  - Moodle instance
  - openSIS instance

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/ali-commits/edu-platform.git
   cd edu-platform
   ```

2. Download openSIS:
   ```bash
   git clone https://github.com/OS4ED/openSIS-Classic.git opensis
   ```

3. Set up SSL certificate storage:
   ```bash
   sh init-acme.sh
   ```

4. Configure your environment:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

5. Start the services:
   ```bash
   docker compose up -d
   ```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure the following:

1. **Version Settings**:
   - `MOODLE_VERSION`: Moodle container version
   - `MOODLE_DB_VERSION`: PostgreSQL version for Moodle
   - `OPENSIS_DB_VERSION`: MariaDB version for openSIS

2. **Domain Configuration**:
   - `TRAEFIK_DOMAIN`: Domain for Traefik dashboard
   - `MOODLE_DOMAIN`: Domain for Moodle LMS
   - `OPENSIS_DOMAIN`: Domain for openSIS

3. **Moodle Settings**:
   - Database credentials
   - Admin user settings
   - Site name

4. **openSIS Settings**:
   - Database credentials
   - Root password

## Security Considerations

1. **Environment Variables**:
   - Never commit `.env` file
   - Use strong passwords
   - Change default admin credentials

2. **SSL Certificates**:
   - Keep `acme.json` permissions at 600
   - Backup `acme.json` regularly

3. **Database Security**:
   - Use strong passwords
   - Regular backups
   - Restrict network access

## Maintenance

### Backups

1. **Database Backups**:
   ```bash
   # Moodle (PostgreSQL)
   docker exec moodle-db pg_dump -U ${MOODLE_DB_USER} ${MOODLE_DB_NAME} > moodle_backup.sql

   # openSIS (MariaDB)
   docker exec opensis-db mysqldump -u ${OPENSIS_DB_USER} -p${OPENSIS_DB_PASS} ${OPENSIS_DB_NAME} > opensis_backup.sql
   ```

2. **Volume Backups**:
   ```bash
   # Create a backup directory
   mkdir -p backups

   # Backup volumes
   docker run --rm -v edu-platform_moodle-data:/source:ro -v $(pwd)/backups:/backup alpine tar czf /backup/moodle-data.tar.gz -C /source ./
   docker run --rm -v edu-platform_opensis-data:/source:ro -v $(pwd)/backups:/backup alpine tar czf /backup/opensis-data.tar.gz -C /source ./
   ```

### Updates

1. **Moodle Updates**:
   - Update version in `.env`
   - Run `docker compose pull moodle`
   - Run `docker compose up -d moodle`

2. **openSIS Updates**:
   - Pull latest from openSIS repository
   - Rebuild container: `docker compose build opensis`
   - Update: `docker compose up -d opensis`

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues**:
   - Verify domain DNS settings
   - Check `acme.json` permissions
   - Review Traefik logs: `docker compose logs traefik`

2. **Database Connection Issues**:
   - Verify credentials in `.env`
   - Check database logs
   - Ensure services are running: `docker compose ps`

### Logs

View service logs:
```bash
# All services
docker compose logs

# Specific service
docker compose logs [service-name]

# Follow logs
docker compose logs -f [service-name]
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Moodle](https://moodle.org/)
- [openSIS](https://www.opensis.com/)
- [Traefik](https://traefik.io/)
- [Docker](https://www.docker.com/)

## Support

For support, please open an issue on the GitHub repository.
