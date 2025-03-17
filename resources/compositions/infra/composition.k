{
    apiVersion = "apiextensions.crossplane.io/v1"
    kind = "Composition"
    metadata = {
        name = "multiazwordpressinfra-composition"
    }
    spec = {
        compositeTypeRef = {
            apiVersion = "segoja7.example/v1alpha1"
            kind = "MultiAzWordpressInfra"
        }
        mode = "Pipeline"
        pipeline = [
            {
                step = "normal"
                functionRef = {
                    name = "function-kcl"
                }
                input = {
                    apiVersion = "krm.kcl.dev/v1alpha1"
                    kind = "KCLRun"
                    metadata = {
                        name = "basic"
                    }
                    spec = {
                        source = r"""providerConfigName = option("params")?.oxr?.spec?.providerConfigName or "segoja7"
region = option("params")?.oxr?.spec.region or "us-east-1"
projectName = option("params")?.oxr?.spec.parameters.projectName or "nodefined"
ec2api = "ec2.aws.crossplane.io/v1beta1"
subnet_configs = [
    {"name": "data-private-subnet-az1", "cidr": "172.16.1.0/24", "zone": "us-east-1a", "type": "private"},
    {"name": "data-private-subnet-az2", "cidr": "172.16.2.0/24", "zone": "us-east-1b", "type": "private"},
    {"name": "app-private-subnet-az1", "cidr": "172.16.3.0/24", "zone": "us-east-1a", "type": "private"},
    {"name": "app-private-subnet-az2", "cidr": "172.16.4.0/24", "zone": "us-east-1b", "type": "private"},
    {"name": "public-subnet-az1", "cidr": "172.16.5.0/24", "zone": "us-east-1a", "type": "public"},
    {"name": "public-subnet-az2", "cidr": "172.16.6.0/24", "zone": "us-east-1b", "type": "public"}
]
routeTableConfigs = [
              {"name": "public", "subnet_type": "public"},
              {"name": "private", "subnet_type": "private"}
]

policyarn = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
]

addons = [
    {"name": "vpc-cni", "version": "v1.19.2-eksbuild.1"},
    {"name": "kube-proxy", "version": "v1.32.0-eksbuild.2"},
    {"name": "coredns", "version": "v1.11.4-eksbuild.2"},
    {"name": "eks-pod-identity-agent", "version": "v1.3.4-eksbuild.1"},
]
additional_tags = [
    {"key": "Owner", "value": project_name},
    {"key": "Environment", "value": "dev"}
]
_resources = [
    {
        apiVersion: ec2api
        kind: "VPC"
        metadata: {
            name: "vpc-" + projectName
        }
        spec: {
            forProvider: {
                cidrBlock: "172.16.0.0/16"
                enableDnsSupport: True
                enableDnsHostNames: True
                region: region
                tags: [
                    {
                        key: "app"
                        value: "wordpress"
                    },
                    {
                        key: "Name"
                        value: "vpc-" + projectName
                    }
                ]
            }
            providerConfigRef: {
                name: providerConfigName
            }
        }
    }
]

_resources += [
    {
        apiVersion: ec2api
        kind: "Subnet"
        metadata: {
            name: subnet.name + "-" + projectName
            labels: {
                layer: subnet.layer
                name: subnet.name
            }
        }
        spec: {
            forProvider: {
                availabilityZone: subnet.zone
                vpcIdSelector: {
                    matchControllerRef: True
                }
                cidrBlock: subnet.cidr
                mapPublicIPOnLaunch: True if subnet.type == "public" else False
                region: region
                tags: [
                    {
                        key: "Name"
                        value: subnet.name + "-" + projectName
                    }
                ]
                }
                providerConfigRef: {
                    name: providerConfigName
                }
            }
    } for subnet in subnet_configs
]
_resources += [
    {
        apiVersion: ec2api
        kind: "Address"
        metadata: {
            name: "eip-" + projectName
        }
        spec: {
            forProvider: {
                tags: [
                    {
                        key: "Name"
                        value: "eip-" + projectName
                    }
                ]
                region: region
            }
            providerConfigRef: {
                name: providerConfigName
            }
        }
    }
]
_resources += [
    {
        apiVersion: ec2api
        kind: "NATGateway"
        metadata: {
            name: "ng-" + projectName
        }
        spec: {
            forProvider: {
                tags: [
                    {
                        key: "Name"
                        value: "ng-" + projectName
                    }
                ]
                region: region
                subnetIdRef: {
                    name: subnet.name + "-" + projectName
                }
                allocationIdRef: {
                    name: "eip-" + projectName
                    
                }
            }
            providerConfigRef: {
                name: providerConfigName
            }
        }
    } for subnet in subnet_configs if subnet.type == "public"
]
items = _resources
"""
                    }
                }
            }
            {
                step = "ready"
                functionRef = {
                    name = "function-auto-ready"
                }
            }     
        ]
    }
}
