# Education Platform Docker Setup

A comprehensive Docker-based deployment solution for educational institutions, featuring Moodle LMS, openSIS (Student Information System), and RosarioSIS with automated SSL certificate management through Traefik. Includes both production and demo environments.

## Features

- **Moodle LMS**: A robust learning management system
- **openSIS**: Complete student information management system
- **RosarioSIS**: Flexible student information system
- **Traefik**: Automatic SSL certificate management and reverse proxy
- **Docker-based**: Easy deployment and scaling
- **Secure by Default**: HTTPS enforced with automatic certificate management
- **Multi-Database Support**: PostgreSQL for Moodle/RosarioSIS and MariaDB for openSIS
- **Demo Environment**: Separate demo instances for training and testing

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

6. (Optional) Set up the demo environment:
   ```bash
   # Make the demo manager script executable
   chmod +x demo-manager.sh

   # Start the demo environment
   ./demo-manager.sh start
   ```

## Configuration

### Production Environment Variables

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

### Demo Environment Variables

Copy `.env.example` to `.env.demo` or use the provided `.env.demo` file and configure:

1. **Domain Configuration**:
   - `MOODLE_DEMO_DOMAIN`: Domain for demo Moodle LMS (default: learn-demo.domain.com)
   - `OPENSIS_DEMO_DOMAIN`: Domain for demo openSIS (default: sis-demo.domain.com)
   - `ROSARIO_DEMO_DOMAIN`: Domain for demo RosarioSIS (default: rosario-demo.domain.com)

2. **Database Credentials**:
   - Separate credentials for each demo service
   - Default strong passwords provided

3. **Admin Credentials**:
   - Demo admin accounts for each service
   - Default strong passwords provided

## Demo Environment

The demo environment provides separate instances of all services for training and testing purposes.

### Managing the Demo Environment

Use the included `demo-manager.sh` script to manage the demo environment:

```bash
# Start the demo environment
./demo-manager.sh start

# Stop the demo environment
./demo-manager.sh stop

# Restart the demo environment
./demo-manager.sh restart

# Check status of demo services
./demo-manager.sh status

# View logs from demo services
./demo-manager.sh logs [service-name]

# Reset the demo environment (WARNING: Deletes all data)
./demo-manager.sh reset
```

### Demo URLs

- Moodle Demo: https://learn-demo.domain.com
- openSIS Demo: https://sis-demo.domain.com
- RosarioSIS Demo: https://rosario-demo.domain.com

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

### Production Backups

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
   docker run --rm -v edu-platform_rosario-data:/source:ro -v $(pwd)/backups:/backup alpine tar czf /backup/rosario-data.tar.gz -C /source ./
   ```

### Demo Environment Backups

The demo environment can be backed up using the same methods as the production environment, but with different volume names:

```bash
# Create a backup directory
mkdir -p demo-backups

# Backup demo volumes
docker run --rm -v edu-platform_moodle-demo-data:/source:ro -v $(pwd)/demo-backups:/backup alpine tar czf /backup/moodle-demo-data.tar.gz -C /source ./
docker run --rm -v edu-platform_opensis-demo-data:/source:ro -v $(pwd)/demo-backups:/backup alpine tar czf /backup/opensis-demo-data.tar.gz -C /source ./
docker run --rm -v edu-platform_rosario-demo-data:/source:ro -v $(pwd)/demo-backups:/backup alpine tar czf /backup/rosario-demo-data.tar.gz -C /source ./
```

### Updates

1. **Moodle Updates**:
   - Update version in `.env`
   - Run `docker compose pull moodle`
   - Run `docker compose up -d moodle`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo pull moodle-demo`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo up -d moodle-demo`

2. **openSIS Updates**:
   - Pull latest from openSIS repository
   - Rebuild container: `docker compose build opensis`
   - Update: `docker compose up -d opensis`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo build opensis-demo`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo up -d opensis-demo`

3. **RosarioSIS Updates**:
   - Update version in `.env` if needed
   - Run `docker compose pull rosario`
   - Run `docker compose up -d rosario`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo pull rosario-demo`
   - For demo: `docker compose -f docker-compose-demo.yaml --env-file .env.demo up -d rosario-demo`

## Troubleshooting

### Common Issues (Production & Demo)

1. **SSL Certificate Issues**:
   - Verify domain DNS settings
   - Check `acme.json` permissions
   - Review Traefik logs: `docker compose logs traefik`

2. **Database Connection Issues**:
   - Verify credentials in `.env`
   - Check database logs
   - Ensure services are running: `docker compose ps`

### Logs

#### Production Logs
```bash
# All services
docker compose logs

# Specific service
docker compose logs [service-name]

# Follow logs
docker compose logs -f [service-name]
```

#### Demo Logs
```bash
# All demo services
docker compose -f docker-compose-demo.yaml --env-file .env.demo logs

# Specific demo service
docker compose -f docker-compose-demo.yaml --env-file .env.demo logs [service-name]

# Follow demo logs (or use the demo-manager.sh script)
docker compose -f docker-compose-demo.yaml --env-file .env.demo logs -f [service-name]
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
- [RosarioSIS](https://www.rosariosis.org/)
- [Traefik](https://traefik.io/)
- [Docker](https://www.docker.com/)

## Support

For support, please open an issue on the GitHub repository.
