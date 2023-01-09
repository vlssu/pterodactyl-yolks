# Yolks

可与翼龙的 Egg 系统(预设)一起使用的精选核心镜像合集。每个镜像都会定期重建，以确保依赖关系始终是最新的。

镜像托管在 `registry.cn-shanghai.aliyuncs.com` 上，并存在于 `games`、`installers` 和 `yolks` 空间下。 在确定镜像将位于哪个空间下时使用以下逻辑：

* `oses` — 包含核心包的基础镜像，帮助您入门。
* `games` — 存储库中 `games` 文件夹中的任何内容。这些是为运行特定游戏或游戏类型而构建的镜像。
* `installers` — `installers` 目录中的任何内容。这些镜像将被用于预设的安装脚本使用，而不是用于实际运行游戏服务器。这些镜像仅旨在通预安装常见的安装依赖项（例如 `curl` 和 `wget`）来减少安装时间和额外网络开支。
* `yolks` — 这些是更通用的图像，允许运行不同类型的游戏或脚本。它们通常只是特定版本的软件，并允许翼龙中的不同预设切换使用环境。例如用于运行机器人、Minecraft 服务器等 Java 或 Python 之类的环境。

所有这些镜像都可用于 `linux/amd64` 和 `linux/arm64` 版本，除非另有说明，要在 arm64 系统上使用这些镜像，不需要对它们的标签进行修改，它们应该可以正常工作。

## 贡献

当向现有镜像添加新版本时，例如 `java v42`，您需要将其添加到 `java` 的子文件夹中，例如 `java/42/Dockerfile`。还请更新正确的 `.github/workflows` 文件，以确保正确标记此新版本。

## 可用镜像

### [Oses](/oses)

* [alpine](/oses/alpine)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:alpine`
* [debian](/oses/debian)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:debian`
* [ubuntu](/oses/ubuntu)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:ubuntu`

### [Bot](/bot)

* [`bastion`](/bot/bastion)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:bot_bastion`
* [`parkertron`](/bot/parkertron)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:bot_parkertron`
* [`redbot`](/bot/red)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:bot_red`
* [`sinusbot`](/bot/sinusbot)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:bot_sinusbot`

### [Box64](/box64)

* [`Box64`](/box64)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:box64`

### [Cassandra](/cassandra)

* [`cassandra_java8_python27`](/cassandra/cassandra_java8_python2)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:cassandra_java11_python2`
* [`cassandra_java11_python3`](/cassandra/cassandra_java11_python3)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:cassandra_java11_python3`

### [Dart](/dart)

* [`dart2.17`](/dart/2.17)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dart_2.17`

### [dotNet](/dotnet)

* [`dotnet2.1`](/dotnet/2.1)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dotnet_2.1`
* [`dotnet3.1`](/dotnet/3.1)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dotnet_3.1`
* [`dotnet5.0`](/dotnet/5)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dotnet_5`
* [`dotnet6.0`](/dotnet/6)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dotnet_6`
* [`dotnet7.0`](/dotnet/7)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:dotnet_7`

### [Erlang](/erlang)

* [`erlang22`](/erlang/22)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:erlang_22`
* [`erlang23`](/erlang/23)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:erlang_23`
* [`erlang24`](/erlang/24)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:erlang_24`

### [Games](/games)

* [`altv`](/games/altv)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:altv`
* [`arma3`](/games/arma3)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:arma3`
* [`dayz`](/games/dayz)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:dayz`
* [`mohaa`](games/mohaa)
  * `ghcr.io/pterodactyl/games:mohaa`  
* [`samp`](/games/samp)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:samp`  
* [`source`](/games/source)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:source`
* [`valheim`](/games/valheim)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:valheim`

### [MCDR](/mcdr)

* [`mcdr_java_8`](/mcdr/8)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:mcdr_java_8`
* [`mcdr_java_11`](/mcdr/11)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:mcdr_java_11`
* [`mcdr_java_16`](/mcdr/16)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:mcdr_java_16`
* [`mcdr_java_17`](/mcdr/17)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/games:mcdr_java_17`

### [Golang](/go)

* [`go1.14`](/go/1.14)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.14`
* [`go1.15`](/go/1.15)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.15`
* [`go1.16`](/go/1.16)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.16`
* [`go1.17`](/go/1.17)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.17`
* [`go1.18`](/go/1.18)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.18`
* [`go1.19`](/go/1.19)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:go_1.19`

### [Java](/java)

* [`java8`](/java/8)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:java_8`
* [`java11`](/java/11)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:java_11`
* [`java16`](/java/16)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:java_16`
* [`java17`](/java/17)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:java_17`
* [`java19`](/java/19)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:java_19`

### [MariaDB](/mariadb)

  * [`MariaDB 10.3`](/mariadb/10.3)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mariadb_10.3`
  * [`MariaDB 10.4`](/mariadb/10.4)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mariadb_10.4`
  * [`MariaDB 10.5`](/mariadb/10.5)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mariadb_10.5`
  * [`MariaDB 10.6`](/mariadb/10.6)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mariadb_10.6`
  * [`MariaDB 10.7`](/mariadb/10.7)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mariadb_10.7`

### [MongoDB](/mongodb)

  * [`MongoDB 4`](/mongodb/4)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mongodb_4`
  * [`MongoDB 5`](/mongodb/5)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mongodb_5`
 * [`MongoDB 6`](/mongodb/6)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mongodb_6`    

### [Mono](/mono)

* [`mono_latest`](/mono/latest)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:mono_latest`

### [Nodejs](/nodejs)

* [`node12`](/nodejs/12)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:nodejs_12`
* [`node14`](/nodejs/14)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:nodejs_14`
* [`node16`](/nodejs/16)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:nodejs_16`
* [`node17`](/nodejs/17)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:nodejs_17`
* [`node18`](/nodejs/18)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:nodejs_18`

### [PostgreSQL](/postgres)

  * [`Postgres 9`](/postgres/9)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_9`
  * [`Postgres 10`](/postgres/10)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_10`
  * [`Postgres 11`](/postgres/11)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_11`
  * [`Postgres 12`](/postgres/12)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_12`
  * [`Postgres 13`](/postgres/13)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_13`
  * [`Postgres 14`](/postgres/14)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:postgres_14`  

### [Python](/python)

* [`python3.7`](/python/3.7)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:python_3.7`
* [`python3.8`](/python/3.8)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:python_3.8`
* [`python3.9`](/python/3.9)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:python_3.9`
* [`python3.10`](/python/3.10)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:python_3.10`
* [`python3.11`](/python/3.11)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:python_3.11`

### [Redis](/redis)

  * [`Redis 5`](/redis/5)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:redis_5`
  * [`Redis 6`](/redis/6)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:redis_6`
  * [`Redis 7`](/redis/7)
    * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:redis_7`

### [Rust](/rust)

* ['rust1.31'](/rust/1.31)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:rust_1.31`
* ['rust1.56'](/rust/1.56)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:rust_1.56`
* ['rust1.60'](/rust/1.60)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:rust_1.60`
* ['rust latest'](/rust/latest)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:rust_latest`

### [SteamCMD](/steamcmd)
* [`SteamCMD Debian lastest`](/steamcmd/debian)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/steamcmd:debian`
* [`SteamCMD Debian Dotnet`](/steamcmd/dotnet)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/steamcmd:dotnet`
* [`SteamCMD Ubuntu latest LTS`](/steamcmd/ubuntu)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/steamcmd:ubuntu`

### [Voice](/voice)
* [`Mumble`](/voice/mumble)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:voice_mumble`
* [`TeaSpeak`](/voice/teaspeak)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:voice_teaspeak`

### [Wine](/wine)

* [`Wine`](/wine)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:wine_latest`
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/yolks:wine_staging`

### [Installation Images](/installers)

* [`alpine-install`](/installers/alpine)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/installers:alpine`
* [`debian-install`](/installers/debian)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/installers:debian`
* [`ubuntu-install`](/installers/ubuntu)
  * `registry.cn-shanghai.aliyuncs.com/pterodactyl-images/installers:ubuntu`
