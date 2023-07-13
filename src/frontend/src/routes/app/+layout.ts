import Cogwheel from '$lib/assets/icons/cogwheel.svg?component';
import GlobeAlt from '$lib/assets/icons/globe-alt.svg?component';
import Home from '$lib/assets/icons/home.svg?component';
import User from '$lib/assets/icons/user.svg?component';
import Users from '$lib/assets/icons/users.svg?component';
import type { LayoutLoad } from './$types';

export const load: LayoutLoad = () => {
	return {
		sections: [
			{ slug: 'home', title: 'Home', icon: Home },
			{ slug: 'connect', title: 'Search', icon: GlobeAlt },
			{ slug: 'friends', title: 'Contacts', icon: Users },
			{ slug: 'profile', title: 'My answers', icon: User },
			{ slug: 'settings', title: 'My profile', icon: Cogwheel }
		]
	};
};
