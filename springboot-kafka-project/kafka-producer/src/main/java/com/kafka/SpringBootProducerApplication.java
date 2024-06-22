//////////////////*************************************************************************////////////////////
//////////////// APACHE KAFKA   ///////////////////////
/*Iniciar ZOOKEEPER
     /opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
 */

/*Iniciar KAFKA
    /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
*/
/*Ver contenido del topic wikimedia_recntchange
    /opt/kafka/bin/kafka-console-consumer.sh --topic wikimedia_recentchange --from-beginning --bootstrap-server localhost:9092
 */

package com.kafka;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SpringBootProducerApplication implements CommandLineRunner {
    public static void main(String args[]){

        SpringApplication.run(SpringBootProducerApplication.class);
    }

    @Autowired
    private WikimediaChangesProducer wikimediaChangesProducer;

    //Metodo de CommandLineRunner
    @Override
    public void run(String... args) throws Exception {
        wikimediaChangesProducer.sendMessage();
    }
}
