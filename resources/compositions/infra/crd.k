{
    apiVersion = "apiextensions.crossplane.io/v1"
    kind = "CompositeResourceDefinition"
    metadata = {
        name = "xmultiazinfras.segoja7.example"
    }
    spec = {
        group = "segoja7.example"
        names = {
            kind = "xMultiAzInfra"
            plural = "xmultiazinfras"
        }
        claimNames = {
            kind = "MultiAzInfraClaim"
            plural = "multiazinfraclaims"
        }
        versions = [
            {
                name = "v1alpha1"
                served = True
                referenceable = True
                $schema = {
                    openAPIV3Schema = {
                        $type = "object"
                        properties = {
                            spec = {
                                $type = "object"
                                properties = {
                                    parameters = {
                                        $type = "object"
                                        properties = {
                                            projectName = {
                                                $type = "string"
                                            }
                                            vpccidrBlock = {
                                                $type = "string"
                                                default = "172.16.0.0/16"
                                            }
                                            region = {
                                                $type = "string"
                                                default = "us-east-1"
                                            }
                                        }
                                        required = [
                                            "region"
                                        ]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        ]
    }
}