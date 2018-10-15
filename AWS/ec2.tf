data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"]
}

resource "aws_instance" "outline-server" {
  ami           = "${data.aws_ami.amazon_linux.id}"
  instance_type = "t2.nano"

  associate_public_ip_address = true
  source_dest_check           = false
  security_groups             = ["${aws_security_group.outline_sg.name}"]
  iam_instance_profile        = "${aws_iam_instance_profile.outline-server_instance_profile.name}"

  key_name = "${aws_key_pair.ec2-key.key_name}"

  user_data = "${data.template_file.deployment_shell_script.rendered}"

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for client config ...'",
      "while [ ! -f /tmp/outline-install-details.txt ]; do sleep 5; done",
      "echo 'DONE!'",
    ]

    connection {
      host        = "${aws_instance.outline-server.public_ip}"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${var.private_key_file}")}"
      timeout     = "1m"
    }
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.private_key_file} ec2-user@${aws_instance.outline-server.public_ip}:/tmp/outline-install-details.txt ${var.client_config_path}/outline-install-details-${aws_instance.outline-server.public_ip}.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Scheduling instance reboot in one minute ...'",
      "sudo shutdown -r +1",
    ]

    connection {
      host        = "${aws_instance.outline-server.public_ip}"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("${var.private_key_file}")}"
      timeout     = "1m"
    }
  }

  provisioner "local-exec" {
    command = "cat ${var.client_config_path}/outline-install-details-${aws_instance.outline-server.public_ip}.txt"
  }

  provisioner "local-exec" {
    command = "rm -f ${var.client_config_path}/outline-install-details-${aws_instance.outline-server.public_ip}.txt"
    when    = "destroy"
  }

  tags {
    Name = "outline-server"
  }
}

resource "aws_iam_role" "outline-server_ec2_role" {
  name = "outline-server_ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "outline-server_instance_profile" {
  name = "outline-server_instance_profile"
  role = "${aws_iam_role.outline-server_ec2_role.name}"
}

resource "aws_iam_role_policy" "outline-server_ec2_role_policy" {
  name = "outline-server_ec2_role_policy"
  role = "${aws_iam_role.outline-server_ec2_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_security_group.outline_sg.arn}"
      ]
    }
  ]
}
EOF
}

data "template_file" "deployment_shell_script" {
  template = "${file("userdata.sh")}"

  vars {
    REGION         = "${var.region}"
    SECURITY_GROUP = "${aws_security_group.outline_sg.name}"
  }
}

resource "aws_key_pair" "ec2-key" {
  key_name_prefix = "outline-key-"
  public_key      = "${file(var.public_key_file)}"
}
