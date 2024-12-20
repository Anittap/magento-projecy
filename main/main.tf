module "magento_vpc" {
  source              = "../modules/vpc"
  cidr_block          = var.cidr_block
  project_name        = var.project_name
  project_environment = var.project_environment
  region              = var.region
  owner               = var.owner
  bits                = var.bits
}
module "sg" {
  source              = "../modules/sg"
  magento_ports       = var.magento_ports
  mysql_ports         = var.mysql_ports
  elasticsearch_ports = var.elasticsearch_ports
  alb_ports           = var.alb_ports
  docker_tcp_ports    = var.docker_tcp_ports
  docker_udp_ports    = var.docker_udp_ports
  ssh_port            = var.ssh_port
  bastion_ports       = var.bastion_ports
  project_name        = var.project_name
  project_environment = var.project_environment
  magento_vpc_id      = module.magento_vpc.vpc_id
  depends_on = [
  module.magento_vpc.vpc_id]
}
module "key_pair" {
  source              = "../modules/key-pair"
  project_name        = var.project_name
  project_environment = var.project_environment
}
module "lt-magento-master" {
  source              = "../modules/lt"
  project_name        = var.project_name
  project_environment = var.project_environment
  sg_magento_id       = module.sg.sg_magento_id
  key_pair            = module.key_pair.key_name
  ami_id_map          = var.ami_id_map
  region              = var.region
  name                = "magento"
  alias               = "master"
  instance_type       = var.instance_type
  owner               = var.owner
  user_data           = filebase64("magento-master.sh")
}
module "master-asg" {
  source                   = "../modules/asg"
  private_subnets          = module.magento_vpc.private_subnet_ids
  lt_id                    = module.lt-magento-master.lt_id
  project_name             = var.project_name
  project_environment      = var.project_environment
  desired_size             = var.other_desired_size
  min_size                 = var.other_min_size
  max_size                 = var.other_max_size
  name                     = "magento"
  alias                    = "master"
  enable_elb_health_checks = var.enable_elb_health_checks
  lt_version               = module.lt-magento-master.lt_version
}
module "lt-magento-worker" {
  source              = "../modules/lt"
  project_name        = var.project_name
  project_environment = var.project_environment
  sg_magento_id       = module.sg.sg_magento_id
  key_pair            = module.key_pair.key_name
  ami_id_map          = var.ami_id_map
  region              = var.region
  name                = "magento"
  alias               = "worker"
  instance_type       = var.instance_type
  owner               = var.owner
  user_data           = filebase64("magento.sh")
}
module "worker-asg" {
  source                   = "../modules/asg"
  private_subnets          = module.magento_vpc.private_subnet_ids
  lt_id                    = module.lt-magento-worker.lt_id
  project_name             = var.project_name
  project_environment      = var.project_environment
  desired_size             = var.magento_desired_size
  min_size                 = var.magento_min_size
  max_size                 = var.magento_max_size
  name                     = "magento"
  alias                    = "worker"
  enable_elb_health_checks = var.enable_elb_health_checks
  lt_version               = module.lt-magento-worker.lt_version
}
module "lt-magento-elasticsearch" {
  source              = "../modules/lt"
  project_name        = var.project_name
  project_environment = var.project_environment
  sg_magento_id       = module.sg.sg_elasticsearch_id
  key_pair            = module.key_pair.key_name
  ami_id_map          = var.ami_id_map
  region              = var.region
  name                = "magento"
  alias               = "elasticsearch"
  instance_type       = var.instance_type
  owner               = var.owner
  user_data           = filebase64("setup.sh")
}
module "elasticsearch-asg" {
  source                   = "../modules/asg"
  private_subnets          = module.magento_vpc.private_subnet_ids
  lt_id                    = module.lt-magento-worker.lt_id
  project_name             = var.project_name
  project_environment      = var.project_environment
  desired_size             = var.other_desired_size
  min_size                 = var.other_min_size
  max_size                 = var.other_max_size
  name                     = "magento"
  alias                    = "elasticsearch"
  enable_elb_health_checks = var.enable_elb_health_checks
  lt_version               = module.lt-magento-elasticsearch.lt_version
}
module "lt-magento-mysql" {
  source              = "../modules/lt"
  project_name        = var.project_name
  project_environment = var.project_environment
  sg_magento_id       = module.sg.sg_mysql_id
  key_pair            = module.key_pair.key_name
  ami_id_map          = var.ami_id_map
  region              = var.region
  name                = "magento"
  alias               = "mysql"
  instance_type       = var.instance_type
  owner               = var.owner
  user_data           = filebase64("setup.sh")
}
module "mysql-asg" {
  source                   = "../modules/asg"
  private_subnets          = module.magento_vpc.private_subnet_ids
  lt_id                    = module.lt-magento-mysql.lt_id
  project_name             = var.project_name
  project_environment      = var.project_environment
  desired_size             = var.other_desired_size
  min_size                 = var.other_min_size
  max_size                 = var.other_max_size
  name                     = "magento"
  alias                    = "mysql"
  enable_elb_health_checks = var.enable_elb_health_checks
  lt_version               = module.lt-magento-mysql.lt_version
}
module "tg" {
  source              = "../modules/tg"
  vpc_id              = module.magento_vpc.vpc_id
  project_name        = var.project_name
  name                = "magento"
  project_environment = var.project_environment
}
module "asg_to_tg_attachment" {
  source = "../modules/asg_to_tg_attachment"
  asg_id = module.worker-asg.id
  tg_arn = module.tg.arn
}
module "alb" {
  source              = "../modules/alb"
  sg_id               = module.sg.sg_alb_id
  public_subnet_ids   = module.magento_vpc.public_subnet_ids
  project_name        = var.project_name
  project_environment = var.project_environment
  certificate_arn     = data.aws_acm_certificate.issued.arn
  name                = "magento"
  alb_arn             = module.alb.arn
  tg_arn              = module.tg.arn
  zone_id             = data.aws_route53_zone.main.zone_id
  domain_name         = data.aws_route53_zone.main.name
}