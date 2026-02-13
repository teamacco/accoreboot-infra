[${environment}]
${environment}-backend ansible_host=${public_ip}

[${environment}:vars]
ansible_user=${ssh_user}
ansible_ssh_private_key_file=${private_key}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
db_host=${db_host}
db_port=${db_port}
db_user=${db_user}
db_password=${db_password}
