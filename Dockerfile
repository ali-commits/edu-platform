# Base Image
FROM php:7.4-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    zip \
    unzip \
    git \
    libzip-dev \
    mariadb-client && \
    docker-php-ext-install mysqli pdo pdo_mysql zip && \
    a2enmod rewrite

# Clone openSIS
COPY opensis /var/www/html/

# Set Permissions
RUN chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html

# Expose HTTP Port
EXPOSE 80

# Start Apache
CMD ["apache2-foreground"]
