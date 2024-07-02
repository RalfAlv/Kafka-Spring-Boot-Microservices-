################################################
###########    JAVA     ########################
################################################

# Función para verificar si Java está instalado
check_java_installed() {
    if type -p java; then
        echo "Java encontrado en el PATH. ......................."
        _java=java
    elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
        echo "Java encontrado en JAVA_HOME. ........................"
        _java="$JAVA_HOME/bin/java"
    else
        echo "Java no encontrado. Instalando OpenJDK 17... ......................."
        sudo apt install openjdk-17-jdk -y
        return
    fi

    if [[ "$_java" ]]; then
        echo "Verificando la versión de Java... ..................................."
        version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}'
        )

        major_version=$(echo $version | awk -F[.] '{print $1}')
         if [[ "$major_version" -eq 17 ]]; then
            echo "Java 17 ya está instalado. ..................................."
        else
            echo "Instalando OpenJDK 17... ......................................."
            sudo apt install openjdk-17-jdk -y
        fi
    fi
}

# Llamada a la función para verificar la instalación de Java
check_java_installed

################################################
###########    KAFKA    ########################
################################################

#!/bin/bash

# Directorio de instalación
KAFKA_DIR="/opt/kafka"

# Función para matar procesos existentes
kill_existing_processes() {
    echo "Verificando y terminando procesos existentes..."

    # Matar ZooKeeper si está en ejecución
    ZOOKEEPER_PID=$(sudo netstat -tlnp | grep :2181 | awk '{print $7}' | cut -d'/' -f1)
    if [ ! -z "$ZOOKEEPER_PID" ]; then
        echo "Terminando proceso ZooKeeper existente (PID: $ZOOKEEPER_PID)..."
        sudo kill $ZOOKEEPER_PID
        sleep 5
    fi

    # Matar Kafka si está en ejecución
    KAFKA_PID=$(sudo netstat -tlnp | grep :9092 | awk '{print $7}' | cut -d'/' -f1)
    if [ ! -z "$KAFKA_PID" ]; then
        echo "Terminando proceso Kafka existente (PID: $KAFKA_PID)..."
        sudo kill $KAFKA_PID
        sleep 5
    fi
}

# Función para verificar si ZooKeeper está activo
check_zookeeper() {
    echo "Verificando ZooKeeper..."
    if echo srvr | nc localhost 2181 | grep -q "Zookeeper version"; then
        echo "ZooKeeper está activo y respondiendo correctamente."
        return 0
    else
        echo "ZooKeeper no está respondiendo correctamente."
        return 1
    fi
}

# Función para verificar si Kafka está activo
check_kafka() {
    echo "Verificando Kafka..."
    if timeout 5 $KAFKA_DIR/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo "Kafka está activo y respondiendo correctamente."
        return 0
    else
        echo "Kafka no está respondiendo correctamente."
        return 1
    fi
}

# Función para iniciar Kafka
start_kafka() {
    if [ -f "$KAFKA_DIR/bin/zookeeper-server-start.sh" ] && [ -f "$KAFKA_DIR/bin/kafka-server-start.sh" ]; then
        echo "Verificando directorios y permisos..."
        sudo mkdir -p /tmp/zookeeper
        sudo chown -R $(whoami):$(whoami) /tmp/zookeeper
        sudo chown -R $(whoami):$(whoami) $KAFKA_DIR

        echo "Iniciando ZooKeeper..."
        sudo $KAFKA_DIR/bin/zookeeper-server-start.sh -daemon $KAFKA_DIR/config/zookeeper.properties
        echo "Esperando 30 segundos para que ZooKeeper se inicie completamente..."
        sleep 30

        # Verificar ZooKeeper
        if ! check_zookeeper; then
            echo "Error al iniciar ZooKeeper. Verificando logs..."
            sudo tail -n 50 $KAFKA_DIR/logs/zookeeper.out
            exit 1
        fi

        echo "Iniciando Kafka..."
        sudo $KAFKA_DIR/bin/kafka-server-start.sh -daemon $KAFKA_DIR/config/server.properties
        echo "Esperando 30 segundos para que Kafka se inicie completamente..."
        sleep 30

        # Verificar Kafka
        if ! check_kafka; then
            echo "Error al iniciar Kafka. Verificando logs..."
            sudo tail -n 50 $KAFKA_DIR/logs/server.log
            exit 1
        fi

        echo "Kafka y ZooKeeper iniciados y funcionando correctamente."
    else
        echo "Error: Los archivos de inicio de Kafka no se encuentran. La instalación puede haber fallado."
        exit 1
    fi
}

# Verifica si Kafka ya está instalado
if [ -d "$KAFKA_DIR" ]; then
    echo "Kafka ya está instalado en $KAFKA_DIR"
    kill_existing_processes
    start_kafka
else
    echo "Kafka no está instalado. Procediendo con la instalación..."

    # Descarga Kafka
    KAFKA_VERSION="3.5.1"
    SCALA_VERSION="2.13"
    KAFKA_TARBALL="kafka_$SCALA_VERSION-$KAFKA_VERSION.tgz"
    KAFKA_URL="https://archive.apache.org/dist/kafka/$KAFKA_VERSION/$KAFKA_TARBALL"

    if wget "$KAFKA_URL" -P /tmp; then
        # Descomprime Kafka en /opt/
        if sudo tar -xzf "/tmp/$KAFKA_TARBALL" -C /opt/; then
            sudo mv "/opt/kafka_$SCALA_VERSION-$KAFKA_VERSION" "$KAFKA_DIR"

            # Cambia el propietario del directorio de Kafka al usuario actual
            sudo chown -R $(whoami):$(whoami) "$KAFKA_DIR"

            # Limpia el archivo descargado
            rm "/tmp/$KAFKA_TARBALL"

            echo "Kafka ha sido instalado en $KAFKA_DIR"

            # Inicia Kafka
            start_kafka
        else
            echo "Error al descomprimir Kafka."
            exit 1
        fi
    else
        echo "Error al descargar Kafka. Por favor, verifica la URL y tu conexión a internet."
        exit 1
    fi
fi

# Verificaciones adicionales
echo "Verificando puerto 2181..."
sudo lsof -i :2181

#echo "Verificando permisos de /tmp/zookeeper..."
#ls -l /tmp/zookeeper

echo "Verificando conexión al puerto 2181..."
nc -vz localhost 2181

#echo "Mostrando contenido de zookeeper.properties..."
#cat $KAFKA_DIR/config/zookeeper.properties


# Verificar si el topic existe
existing_topic=$(/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 | grep "wikimedia_recentchange")

if [ -z "$existing_topic" ]; then
    # Si el topic no existe, crearlo
    echo "Creando el topic wikimedia_recentchange"
    /opt/kafka/bin/kafka-topics.sh --create --topic wikimedia_recentchange --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
else
    echo "El topic wikimedia_recentchange ya existe."
fi

# Listar todos los topics
echo "Listando todos los topics:"
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092



echo "Creando el topic wikimedia_recentchange"

    /opt/kafka/bin/kafka-topics.sh --create --topic wikimedia_recentchange --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1

echo "List Topics"

    /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092


################################################
###########    MYSQL    ########################
################################################

#!/bin/bash

# Función para verificar e instalar MySQL
install_mysql() {
    if ! command -v mysql &> /dev/null; then
        echo "MySQL no está instalado. Procediendo con la instalación..."
        sudo apt update
        sudo apt install -y mysql-server
        if [ $? -ne 0 ]; then
            echo "Error al instalar MySQL."
            exit 1
        fi
    else
        echo "MySQL ya está instalado."
    fi
}

# Función para configurar MySQL
configure_mysql() {
    MYSQL_ROOT_PASSWORD="raptoradmin"

    # Iniciar y habilitar el servicio MySQL
    echo "Iniciando el servicio MySQL..."
    sudo systemctl start mysql
    echo "Habilitando el inicio automático de MySQL..."
    sudo systemctl enable mysql

    # Establecer contraseña para el usuario root
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';"

    # Crear usuario, base de datos y tabla en MySQL
    echo "Creando usuario, base de datos y tabla en MySQL..."
    mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOSQL
    CREATE DATABASE IF NOT EXISTS wikimedia;
    CREATE USER IF NOT EXISTS 'raptor'@'localhost' IDENTIFIED BY 'admin';
    GRANT ALL PRIVILEGES ON wikimedia.* TO 'raptor'@'localhost';
    FLUSH PRIVILEGES;
    USE wikimedia;
    CREATE TABLE IF NOT EXISTS wikimedia_recentchange (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        wiki_event_data TEXT
    );
EOSQL

    if [ $? -eq 0 ]; then
        echo "Configuración de MySQL completada correctamente."
        echo "Usuario creado: raptor"
        echo "Contraseña: admin"
        echo "Base de datos: wikimedia"
        echo "Tabla: wikimedia_recentchange"
    else
        echo "Error en la configuración de MySQL."
        exit 1
    fi
}

# Ejecutar las funciones
install_mysql
configure_mysql


################################################
###### Intellij IDEA Community  y Git  #########
################################################


    # Función para verificar e instalar Git
    install_git() {
        if ! command -v git &> /dev/null; then
            echo "Git no está instalado. Instalando..."
            sudo apt update
            sudo apt install -y git
            if [ $? -ne 0 ]; then
                echo "Error al instalar Git."
                exit 1
            fi
        else
            echo "Git ya está instalado."
        fi
    }

    # Función para verificar e instalar IntelliJ IDEA Community
    install_intellij() {
        if ! command -v idea &> /dev/null; then
            echo "IntelliJ IDEA Community no está instalado. Instalando..."
            sudo snap install intellij-idea-community --classic
            if [ $? -ne 0 ]; then
                echo "Error al instalar IntelliJ IDEA Community."
                exit 1
            fi
        else
            echo "IntelliJ IDEA Community ya está instalado."
        fi
    }

    # Clonar el repositorio de GitHub
    clone_repository() {
        local repo_dir="Kafka-Spring-Boot-Microservices-"

        if [ -d "$repo_dir" ]; then
            echo "El directorio $repo_dir ya existe."
            read -p "¿Deseas eliminarlo y clonar de nuevo? (y/n): " answer
            if [ "$answer" != "y" ]; then
                echo "Saliendo del script."
                exit 1
            fi
            echo "Eliminando el directorio $repo_dir..."
            rm -rf "$repo_dir"
        fi

        echo "Clonando el repositorio Kafka-Spring-Boot-Microservices-..."
        git clone https://github.com/RalfAlv/Kafka-Spring-Boot-Microservices-.git "$repo_dir"
        if [ $? -ne 0 ]; then
            echo "Error al clonar el repositorio."
            exit 1
        fi
    }

    # Abrir el proyecto en IntelliJ IDEA Community
    open_in_intellij() {
        cd Kafka-Spring-Boot-Microservices- || exit
        echo "Abriendo en IntelliJ IDEA Community..."
        /snap/bin/intellij-idea-community .
    }

    # Ejecutar las funciones
    install_git
    install_intellij
    clone_repository
    open_in_intellij

