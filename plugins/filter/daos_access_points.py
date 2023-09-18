def daos_access_points(instances):
    length = len(instances)

    if length <= 7 and length % 2 == 1:
        return instances
    elif length <= 6 and length % 2 == 0:
        return instances[:-1]
    elif length > 7:
        return instances[:7]
    else:
        return []

class FilterModule(object):
    def filters(self):
        return {
            'daos_access_points': daos_access_points
        }
