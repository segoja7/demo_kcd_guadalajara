{
    apiVersion = "apiextensions.crossplane.io/v1"
    kind = "Composition"
    metadata = {
        name = "infra-composition"
    }
    spec = {
        compositeTypeRef = {
            apiVersion = "segoja7.example/v1alpha1"
            kind = "XMultiAzInfra"
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
iamapi = "iam.aws.crossplane.io/v1beta1"
subnet_configs = [
    {"name": "data-private-subnet-az1", "cidr": "172.16.1.0/24", "zone": "us-east-1a", "type": "private", "layer": "data"},
    {"name": "data-private-subnet-az2", "cidr": "172.16.2.0/24", "zone": "us-east-1b", "type": "private", "layer": "data"},
    {"name": "app-private-subnet-az1", "cidr": "172.16.3.0/24", "zone": "us-east-1a", "type": "private", "layer": "app"},
    {"name": "app-private-subnet-az2", "cidr": "172.16.4.0/24", "zone": "us-east-1b", "type": "private", "layer": "app"},
    {"name": "public-subnet-az1", "cidr": "172.16.5.0/24", "zone": "us-east-1a", "type": "public",  "layer": "internet"},
    {"name": "public-subnet-az2", "cidr": "172.16.6.0/24", "zone": "us-east-1b", "type": "public", layer: "internet"}
]
routeTableConfigs = [
              {"name": "public",},
              {"name": "private",}
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
        kind: "InternetGateway"
        metadata: {
            name: "igw-" + projectName
        }
        spec: {
            forProvider: {
                vpcIdSelector: {
                    matchControllerRef: True
                }
                region: region
                tags: [
                    {
                        key: "Name"
                        value: "igw-" + projectName
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
_resources += [
    {
        apiVersion: ec2api
        kind: "RouteTable"
        metadata: {
            name: "rt-" + routeTable.name + "-" + projectName
            labels: {
                type: routeTable.name
            }
        }
        spec: {
            forProvider: {
                if routeTable.name == "public":
                    associations = [{
                        subnetIdRef = {
                            name = subnet.name + "-" + projectName
                        }
                    } for subnet in subnet_configs if subnet.type == "public"]
                    
                    routes = [  #deprecated
                        {
                            destinationCidrBlock = "0.0.0.0/0"
                            gatewayIdSelector = {
                                matchControllerRef = True
                            }
                        }
                    ]
                else:
                    associations = [{
                        subnetIdRef = {
                            name = subnet.name + "-" + projectName
                        }
                    } for subnet in subnet_configs if subnet.type == "private"]
                    routes = [  #deprecated
                        {
                            destinationCidrBlock = "0.0.0.0/0"
                            natGatewayIdSelector  = {
                                matchControllerRef = True
                            }
                        }
                    ]
                vpcIdSelector: {
                    matchControllerRef: True
                }                                 
                region: region
                tags: [
                    {
                        key: "Name"
                        value: "rt-" + routeTable.name + "-" + projectName
                    }
                ]
            }
            providerConfigRef: {
                name: providerConfigName
            }
        }
    } for routeTable in routeTableConfigs
]
import json

_resources += [
    {
        apiVersion = iamapi
        kind = "Role"
        metadata = {
            name = "clusterrole-" + projectName
            labels = {
                role = "clusterrole-" + projectName 
            }
        }
        spec = {
            forProvider = {
                assumeRolePolicyDocument = json.encode({
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Service": ["eks.amazonaws.com"]
                            },
                            "Action": ["sts:AssumeRole"]
                        }
                    ]
                })
                description = "Role for EKS cluster"
                tags = [
                    {
                        key = "Name"
                        value = "role-" + projectName
                    }
                ]
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    }
]
_resources += [
    {
        apiVersion = iamapi
        kind = "RolePolicyAttachment"
        metadata = {
            name = "clusterrolepolicy-" + projectName
        }
        spec = {
            forProvider = {
                policyArn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
                roleName = "clusterrole-" + projectName
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    }
]
_resources += [
    {
        apiVersion = iamapi
        kind = "Role"
        metadata = {
            name = "clusternoderole-" + projectName
            labels = {
                type = "clusternoderole-" + projectName
            }
        }
        spec = {
            forProvider = {
                assumeRolePolicyDocument = json.encode({
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Service": ["ec2.amazonaws.com"]
                            },
                            "Action": ["sts:AssumeRole"]
                        }
                    ]
                })
                tags = [
                    {
                        key = "Name"
                        value = "clusternoderole-" + projectName
                    }
                ]                 
                description = "Role for cluster node"               
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    }
]
_resources += [
    {
        apiVersion = iamapi
        kind = "RolePolicyAttachment"
        metadata = {
            name = "clusternoderolepolicy-" + projectName + "-" + str(policy + 1)
        }
        spec = {
            forProvider = {
                policyArn = policyarn[policy]
                roleName = "clusternoderole-" + projectName
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    } for policy in range(len(policyarn))
]
_resources += [
    {
        apiVersion = iamapi
        kind = "Role"
        metadata = {
            name = "clusteradminrole-" + projectName
        }
        spec = {
            forProvider = {
                assumeRolePolicyDocument = json.encode({
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Service": ["pods.eks.amazonaws.com"]
                            },
                            "Action": ["sts:AssumeRole", "sts:TagSession"]
                        }
                    ]
                })
                tags = [
                    {
                        key = "Name"
                        value = "clusternoderole-" + projectName
                    }
                ]                 
                description = "Role for cluster node"             
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    }
]
_resources += [
    {
        apiVersion = iamapi
        kind = "RolePolicyAttachment"
        metadata = {
            name = "clusteradminrolepolicy-" + projectName
        }
        spec = {
            forProvider = {
                policyArn = "arn:aws:iam::aws:policy/AdministratorAccess"
                roleName = "clusteradminrole-" + projectName
            }
            providerConfigRef = {
                name = providerConfigName
            }
        }
    } for policy in range(len(policyarn))
]
_resources += [
    {
        apiVersion = "eks.aws.crossplane.io/v1beta1"
        kind = "Cluster"
        metadata = {
            name = "cluster-" + projectName
            labels ={
                name = "cluster-" + projectName
            }
        }
        spec = {
            forProvider = {
                accessConfig = {
                    authenticationMode = "API_AND_CONFIG_MAP"
                }
                roleArnSelector = {
                    matchControllerRef = True
                    matchLabels = {
                        role = "clusterrole-" + projectName
                    }
                }
                resourcesVpcConfig = {
                    endpointPrivateAccess = True
                    endpointPublicAccess = True
                    subnetIdSelector = {
                        matchControllerRef = True
                        matchLabels = {
                            layer = "app"
                        } 
                    }
                }
                tags = {
                    "Name": "cluster-" + projectName
                }
                region = region                                                
            }
            providerConfigRef = {
                name = providerConfigName
            }
            writeConnectionSecretToRef = {
                name = "cluster-" + projectName
                namespace = "default"
            }            
        }
    } 
]
_resources += [
    {
        apiVersion = "eks.aws.crossplane.io/v1alpha1"
        kind = "NodeGroup"
        metadata = {
            name = "nodegroup-" + projectName
        }
        spec = {
            forProvider = {
                diskSize = 20
                instanceTypes = [
                    "t3.medium"
                ]
                clusterNameSelector = {
                    matchControllerRef = True
                    matchLabels = {
                        name = "cluster-" + projectName
                    }
                }
                subnetSelector = {
                    matchControllerRef = True
                    matchLabels = {
                        layer = "app"
                    }
                }   
                nodeRoleSelector = {
                    matchControllerRef = True
                    matchLabels = {
                        type = "clusternoderole-" + projectName
                    }
                }
                updateConfig = {
                    maxUnavailable = 1
                }
                scalingConfig = {
                    minSize = 1
                    maxSize = 1
                    desiredSize = 1
                }

                tags = {
                    "Name": "nodegroup-" + projectName
                }
                region = region                                                
            }
            providerConfigRef = {
                name = providerConfigName
            }          
        }
    }
]
_resources += [
    {
        apiVersion = "eks.aws.crossplane.io/v1alpha1"
        kind = "Addon"
        metadata = {
            name = "addon-" + addon.name + "-" + projectName
        }
        spec = {
            forProvider = {
                addonName = addon.name
                addonVersion = addon.version
                clusterNameSelector = {
                    matchControllerRef = True
                    matchLabels = {
                        name = "cluster-" + projectName
                    }
                }
                region = region
            }
            providerConfigRef = {
                name = providerConfigName
            }                       
        }
    } for addon in addons
] 
_resources += [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha1"
        kind = "ProviderConfig"
        metadata = {
            name = "k8s-provider" + projectName
        }
        spec = {
            credentials = {
                source = "Secret"
                secretRef = {
                key = "kubeconfig"
                name = "cluster-" + projectName
                namespace = "default"
                }
            }         
        }
    }
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



