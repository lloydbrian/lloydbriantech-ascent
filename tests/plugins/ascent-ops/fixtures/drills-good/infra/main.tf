# Orders database: Multi-AZ with seven days of automated backups.
resource "aws_db_instance" "orders" {
  identifier              = "orders"
  engine                  = "postgres"
  engine_version          = "16.4"
  instance_class          = "db.t4g.medium"
  multi_az                = true
  backup_retention_period = 7
  storage_encrypted       = true
}
