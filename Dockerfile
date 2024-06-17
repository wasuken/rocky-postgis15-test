# ベースイメージとしてRocky Linux 9を使用
FROM rockylinux:9

# 必要なリポジトリを追加し、GDALとその依存関係、PostgreSQL 15とPostGISをインストール
RUN dnf install -y epel-release && \
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf -qy module disable postgresql && \
    dnf install -y --skip-broken postgresql15-server postgresql15 postgresql15-contrib

RUN dnf --enablerepo=crb install -y flexiblas-netlib64 libqhull_r && \
  dnf install -y --skip-broken gdal35 && \
  dnf install -y postgis33_15
# PostgreSQLのデータベース初期化
USER postgres
RUN /usr/pgsql-15/bin/initdb -D /var/lib/pgsql/15/data

# PostgreSQLの設定ファイルを修正してリモート接続を許可
RUN echo "listen_addresses='*'" >> /var/lib/pgsql/15/data/postgresql.conf && \
    echo "host all all 0.0.0.0/0 md5" >> /var/lib/pgsql/15/data/pg_hba.conf

# ユーザーを再度rootに変更
USER root

# コンテナ起動時にPostgreSQLを起動するスクリプトを作成
RUN echo -e "#!/bin/bash\n\
              su - postgres -c \"/usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data start\"\n\
              sleep 5\n\
              su - postgres -c \"psql -tc \\\"SELECT 1 FROM pg_database WHERE datname = 'mydatabase';\\\" | grep -q 1 || createdb mydatabase\"\n\
              su - postgres -c \"psql -c \\\"CREATE EXTENSION IF NOT EXISTS postgis;\\\" -d mydatabase\"\n\
              tail -f /dev/null" > /start.sh

RUN chmod +x /start.sh

# ポートを公開
EXPOSE 5432

# 起動スクリプトをCMDとして設定
CMD ["/bin/bash", "/start.sh"]
