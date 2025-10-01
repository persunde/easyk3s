FROM squidfunk/mkdocs-material:latest
COPY . /docs
WORKDIR /docs
EXPOSE 8000
CMD ["serve", "--dev-addr=0.0.0.0:8000"]
