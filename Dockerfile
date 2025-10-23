FROM kong:latest

# Copy Kong declarative configuration
COPY kong.yml /usr/local/kong/declarative/kong.yml

# Set proper permissions
USER root
RUN chown -R kong:kong /usr/local/kong/declarative
USER kong

# Kong will read config from KONG_DECLARATIVE_CONFIG env var
# (set in Terraform: /usr/local/kong/declarative/kong.yml)