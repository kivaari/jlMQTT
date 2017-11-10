include("basic.jl")
include("testlib.jl")

using MQTT
import MQTT.Message
using Base.Test

function on_msg(topic, payload)
    info("Received message topic: [", topic, "] payload: [", String(payload), "]")
    @test topic == "abc"
    @test String(payload)== "qwerty"
end

function is_out_correct(filename_expected::AbstractString, actual::Channel{UInt8})
    file = open(filename_expected, "r")
    correct = true
    while !eof(file)
        if read(file, UInt8) != take!(actual)
            correct = false
            break
        end
    end
    if isready(actual)
        correct = false
    end
    return correct
end

function test()
    client = Client(on_msg)

    info("Testing connect")
    connect(client, "test.mosquitto.org", client_id="TestID")
    tfh::TestFileHandler = client.socket
    @test is_out_correct("data/output/connect.dat", tfh.out_channel)

    info("Testing subscribe")
    subscribe_async(client, "abc", 0x01, "cba", 0x00)
    put_from_file(tfh, "data/input/suback.dat")
    @test is_out_correct("data/output/subreq.dat", tfh.out_channel)

    info("Testing publish")
    put_from_file(tfh, "data/input/publish.dat")
    publish_async(client, "test1", "QOS_0", qos=0x00)
    @test is_out_correct("data/output/qos0pub.dat", tfh.out_channel)
    publish_async(client, "test2", "QOS_1", qos=0x01)
    put_from_file(tfh, "data/input/puback.dat")
    @test is_out_correct("data/output/qos1pub.dat", tfh.out_channel)

    info("Testing unsubscribe")
    unsubscribe_async(client, "abc", "cba")
    put_from_file(tfh, "data/input/unsuback.dat")
    @test is_out_correct("data/output/unsubreq.dat", tfh.out_channel)

    info("Testing disconnect")
    disconnect(client)
    @test is_out_correct("data/output/disco.dat", tfh.out_channel)

    sleep(2)
end

test()
